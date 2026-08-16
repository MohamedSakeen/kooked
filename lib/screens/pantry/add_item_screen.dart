import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../utils/constants.dart';
import '../../services/firestore_service.dart';
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
  String _selectedCategory = 'Produce';
  double _quantity = 1;
  String _unit = 'pcs';
  String _selectedType = 'Raw';
  bool _isLoading = false;

  static const List<String> _units = [
    'pcs', 'g', 'kg', 'ml', 'L', 'cups', 'tbsp', 'tsp', 'oz', 'lb',
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
    }
  }

  Future<void> _loadItem() async {
    // TODO: Fetch existing item data for edit mode
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      if (widget.isEditing) {
        await _firestore.updatePantryItem(
          _householdId,
          widget.editItemId!,
          {
            'name': _nameController.text.trim(),
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
          name: _nameController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Item' : 'Add Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item Name', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(hintText: 'e.g. Tomatoes, Milk, Leftover Curry'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Text('Category', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.pantryCategories.map((cat) {
                  final selected = cat == _selectedCategory;
                  final emoji = AppConstants.categoryIcons[cat] ?? '📦';
                  return ChoiceChip(
                    label: Text('$emoji $cat'),
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
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              Text('Type', style: Theme.of(context).textTheme.titleSmall),
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
