import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/cooking_history.dart';

class CookingConfirmationDialog extends StatefulWidget {
  final String recipeTitle;
  final int servings;
  final List<CookedIngredient> ingredients;
  final VoidCallback? onCancel;

  const CookingConfirmationDialog({
    super.key,
    required this.recipeTitle,
    required this.servings,
    required this.ingredients,
    this.onCancel,
  });

  @override
  State<CookingConfirmationDialog> createState() =>
      _CookingConfirmationDialogState();
}

class _CookingConfirmationDialogState
    extends State<CookingConfirmationDialog> {
  late List<CookedIngredient> _editedIngredients;

  @override
  void initState() {
    super.initState();
    _editedIngredients = widget.ingredients
        .map((i) => CookedIngredient(
              name: i.name,
              quantityConsumed: i.quantityConsumed,
              unit: i.unit,
              pantryItemId: i.pantryItemId,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.restaurant_menu,
                      color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Confirm Consumption',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.recipeTitle} • ${widget.servings} serving${widget.servings > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // AI note
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI estimated consumption below. Adjust quantities if needed.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),

            // Ingredient list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _editedIngredients.length,
                itemBuilder: (context, index) {
                  final ing = _editedIngredients[index];
                  return _buildIngredientTile(index, ing);
                },
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onCancel ?? () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, _editedIngredients);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirm & Update Pantry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientTile(int index, CookedIngredient ing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ing.pantryItemId != null
            ? AppColors.success.withValues(alpha: 0.06)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ing.pantryItemId != null
              ? AppColors.success.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ing.pantryItemId != null
                ? Icons.check_circle
                : Icons.help_outline,
            size: 18,
            color: ing.pantryItemId != null
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ing.name,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          // Quantity adjuster
          _buildQtyButton(
            icon: Icons.remove,
            onTap: () {
              setState(() {
                final newQty = _editedIngredients[index].quantityConsumed - 0.5;
                final finalQty = newQty > 0 ? newQty : 0.0;
                final updated = CookedIngredient(
                  name: ing.name,
                  quantityConsumed: finalQty,
                  unit: ing.unit,
                  pantryItemId: ing.pantryItemId,
                );
                _editedIngredients[index] = updated;
                try {
                  widget.ingredients[index] = updated;
                } catch (_) {}
              });
            },
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${_editedIngredients[index].quantityConsumed % 1 == 0 ? _editedIngredients[index].quantityConsumed.toInt() : _editedIngredients[index].quantityConsumed} ${ing.unit}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          _buildQtyButton(
            icon: Icons.add,
            onTap: () {
              setState(() {
                final newQty = _editedIngredients[index].quantityConsumed + 0.5;
                final updated = CookedIngredient(
                  name: ing.name,
                  quantityConsumed: newQty,
                  unit: ing.unit,
                  pantryItemId: ing.pantryItemId,
                );
                _editedIngredients[index] = updated;
                try {
                  widget.ingredients[index] = updated;
                } catch (_) {}
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
