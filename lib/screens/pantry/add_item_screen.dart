import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../utils/constants.dart';
import '../../services/firestore_service.dart';
import '../../services/food_classification_service.dart';
import '../../models/pantry_item.dart';
import '../../widgets/quantity_selector.dart';

class AddItemScreen extends StatefulWidget {
  final String? editItemId;

  const AddItemScreen({super.key, this.editItemId});

  bool get isEditing => editItemId != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _firestore = FirestoreService();
  final _classifier = FoodClassificationService();

  String _selectedCategory = 'Produce';
  double _quantity = 1;
  String _unit = 'pcs';
  String _selectedType = 'Raw';
  bool _isLoading = false;
  bool _showClassificationOverride = false;
  bool _isAmbiguous = false;
  bool _isClassifying = false;
  FoodClassificationResult? _classificationResult;

  static const List<String> _units = [
    'pcs', 'g', 'kg', 'ml', 'L', 'cups', 'tbsp', 'tsp', 'oz', 'lb', 'bowl', 'servings', 'packet', 'bunch', 'slice',
  ];

  String get _householdId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'demo';
  }

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadItem();
    } else {
      _nameController.addListener(_onNameChanged);
    }
  }

  Future<void> _loadItem() async {
    // Edit mode: fetch existing item data if editItemId is provided
    try {
      final items = await _firestore.getPantryItems(_householdId);
      final existing = items.firstWhere(
        (i) => i.id == widget.editItemId,
        orElse: () => PantryItem(
          id: '',
          name: '',
          category: 'Other',
          quantity: 1,
          unit: 'pcs',
          type: 'Raw',
          dateAdded: DateTime.now(),
          addedBy: '',
          householdId: _householdId,
        ),
      );
      if (existing.id.isNotEmpty && mounted) {
        setState(() {
          _nameController.text = existing.name;
          _selectedCategory = existing.category;
          _quantity = existing.quantity;
          _unit = existing.unit;
          _selectedType = existing.type;
          _showClassificationOverride = true; // allow editing category/type when editing item
        });
      }
    } catch (_) {}
  }

  void _onNameChanged() async {
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _classificationResult = null;
        _isAmbiguous = false;
      });
      return;
    }

    setState(() => _isClassifying = true);
    final result = await _classifier.classify(text);

    if (mounted && _nameController.text.trim() == text) {
      setState(() {
        _classificationResult = result;
        _selectedCategory = result.category;
        _selectedType = result.type;
        _isAmbiguous = result.isAmbiguous;
        _isClassifying = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final inputName = _nameController.text.trim();
      final canonicalName = FoodClassificationService.normalizeName(inputName);

      // Perform classification if not already determined
      if (_classificationResult == null && !widget.isEditing) {
        final result = await _classifier.classify(inputName);
        _selectedCategory = result.category;
        _selectedType = result.type;
      }

      // Check for duplicates in non-edit mode
      if (!widget.isEditing) {
        final existingItems = await _firestore.getPantryItems(_householdId);
        final duplicate = FoodClassificationService.findDuplicate(inputName, existingItems);

        if (duplicate != null && mounted) {
          final shouldMerge = await _showDuplicateDialog(duplicate, _quantity, _unit);
          if (shouldMerge == true) {
            final newQty = duplicate.quantity + _quantity;
            await _firestore.updatePantryItem(
              _householdId,
              duplicate.id,
              {'quantity': newQty},
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Updated ${duplicate.name} quantity to $newQty ${duplicate.unit}'),
                  backgroundColor: AppColors.success,
                ),
              );
              context.pop();
            }
            return;
          }
        }
      }

      if (widget.isEditing) {
        await _firestore.updatePantryItem(
          _householdId,
          widget.editItemId!,
          {
            'name': canonicalName.isNotEmpty ? canonicalName : inputName,
            'category': _selectedCategory,
            'quantity': _quantity,
            'unit': _unit,
            'type': _selectedType,
          },
        );
      } else {
        final user = FirebaseAuth.instance.currentUser;
        final item = PantryItem(
          id: '',
          name: canonicalName.isNotEmpty ? canonicalName : inputName,
          category: _selectedCategory,
          quantity: _quantity,
          unit: _unit,
          type: _selectedType,
          dateAdded: DateTime.now(),
          addedBy: user?.uid ?? '',
          householdId: _householdId,
        );
        await _firestore.addPantryItem(_householdId, item);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Item updated!' : 'Item added!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<bool?> _showDuplicateDialog(PantryItem existing, double addQty, String addUnit) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Item already in pantry'),
        content: Text(
          'You already have ${existing.name} (${existing.quantity} ${existing.unit}) in your pantry.\n\nWould you like to add $addQty $addUnit to your existing stock?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Add Separate Item'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Merge Quantities'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = AppConstants.categoryIcons[_selectedCategory] ?? '📦';

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Item' : 'Add Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Food Item', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Tomatoes, Milk, Leftover Curry',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Classification Preview Badge & Clarification
              if (_isClassifying)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(width: 8),
                      Text('Classifying...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              else if (_nameController.text.trim().isNotEmpty && _classificationResult != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            '$_selectedCategory • $_selectedType',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showClassificationOverride = !_showClassificationOverride;
                        });
                      },
                      child: Text(
                        _showClassificationOverride ? 'Hide' : 'Correct',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Ambiguity Clarification UI
              if (_isAmbiguous && !_showClassificationOverride) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How should we treat "${_nameController.text.trim()}"?',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedType = 'Raw';
                                  _isAmbiguous = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _selectedType == 'Raw' ? AppColors.primary : AppColors.divider,
                                ),
                              ),
                              child: const Text('Raw Ingredient', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = 'Leftovers';
                                  _selectedType = 'Leftover';
                                  _isAmbiguous = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _selectedType == 'Leftover' ? AppColors.primary : AppColors.divider,
                                ),
                              ),
                              child: const Text('Leftover Cooked', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Optional Manual Override Selectors
              if (_showClassificationOverride) ...[
                Text('Category (Override)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.pantryCategories.map((cat) {
                    final selected = cat == _selectedCategory;
                    final catEmoji = AppConstants.categoryIcons[cat] ?? '📦';
                    return ChoiceChip(
                      label: Text('$catEmoji $cat'),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Type (Override)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: AppConstants.itemTypes.map((type) {
                    final selected = type == _selectedType;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(type, textAlign: TextAlign.center),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedType = type),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          checkmarkColor: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 12),
              Text('Quantity', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  QuantitySelector(
                    quantity: _quantity,
                    unit: _unit,
                    onChanged: (val) => setState(() => _quantity = val),
                    step: _unit == 'pcs' ? 1 : 0.5,
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _unit,
                        items: _units
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _unit = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEditing ? 'Update Item' : 'Add Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
