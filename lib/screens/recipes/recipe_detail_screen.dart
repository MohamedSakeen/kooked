import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';
import '../../services/cooking_service.dart';
import '../../models/recipe.dart';
import '../../models/pantry_item.dart';
import '../../models/shopping_item.dart';
import '../../models/cooking_history.dart';
import '../../widgets/cooking_confirmation_dialog.dart';

class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final householdId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';

    return StreamBuilder<List<Recipe>>(
      stream: firestore.recipesStream(),
      builder: (context, recipeSnap) {
        if (recipeSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final recipes = recipeSnap.data ?? [];
        final recipe = recipes.where((r) => r.id == recipeId).firstOrNull;

        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe')),
            body: const Center(child: Text('Recipe not found')),
          );
        }

        return StreamBuilder<List<PantryItem>>(
          stream: firestore.pantryStream(householdId),
          builder: (context, pantrySnap) {
            final pantryItems = pantrySnap.data ?? [];

            // Enrich ingredients with pantry status
            final pantryNames = pantryItems
                .map((i) => i.name.toLowerCase().trim())
                .toSet();

            final enrichedIngredients = recipe.ingredients.map((ing) {
              return RecipeIngredient(
                name: ing.name,
                quantity: ing.quantity,
                unit: ing.unit,
                inPantry:
                    pantryNames.contains(ing.name.toLowerCase().trim()),
              );
            }).toList();

            final allInPantry = enrichedIngredients.every((i) => i.inPantry);
            final missingCount =
                enrichedIngredients.where((i) => !i.inPantry).length;
            final missingIngredients =
                enrichedIngredients.where((i) => !i.inPantry).toList();

            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        recipe.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      background: recipe.imageUrl != null
                          ? Image.network(recipe.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _buildPlaceholder())
                          : _buildPlaceholder(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info row
                          Row(
                            children: [
                              _buildInfoChip(Icons.access_time,
                                  '${recipe.totalTimeMinutes}m'),
                              const SizedBox(width: 12),
                              _buildInfoChip(Icons.people,
                                  '${recipe.servings} servings'),
                              const SizedBox(width: 12),
                              _buildInfoChip(
                                  Icons.restaurant, recipe.cuisine),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: recipe.difficulty == 'Easy'
                                      ? AppColors.success
                                      : recipe.difficulty == 'Medium'
                                          ? AppColors.warning
                                          : AppColors.error,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  recipe.difficulty,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (recipe.isAiGenerated) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'AI Generated',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],

                          // Ingredients
                          const SizedBox(height: 20),
                          Text('Ingredients',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          ...enrichedIngredients.map((ing) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: ing.inPantry
                                    ? AppColors.success.withValues(alpha: 0.08)
                                    : AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ing.inPantry
                                      ? AppColors.success
                                          .withValues(alpha: 0.2)
                                      : AppColors.error
                                          .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    ing.inPantry
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 18,
                                    color: ing.inPantry
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ing.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    '${ing.quantity % 1 == 0 ? ing.quantity.toInt() : ing.quantity} ${ing.unit}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Steps
                          const SizedBox(height: 24),
                          Text('Steps',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          ...recipe.steps.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: const TextStyle(
                                          height: 1.5, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 20),

                          // Action buttons
                          if (allInPantry)
                            _CookNowButton(
                              recipe: recipe,
                              pantryItems: pantryItems,
                              householdId: householdId,
                            )
                          else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) return;

                                  final items = missingIngredients
                                      .map((ing) => ShoppingItemData(
                                            name: ing.name,
                                            quantity: ing.quantity,
                                            unit: ing.unit,
                                          ))
                                      .toList();

                                  final firestore = FirestoreService();
                                  final shoppingItems = items
                                      .map((i) => ShoppingItem(
                                            id: '',
                                            name: i.name,
                                            quantity: i.quantity,
                                            unit: i.unit,
                                            householdId: householdId,
                                          ))
                                      .toList();

                                  await firestore.batchAddShoppingItems(
                                      householdId, shoppingItems);

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${items.length} missing items added to shopping list'),
                                      ),
                                    );
                                  }
                                },
                                icon:
                                    const Icon(Icons.add_shopping_cart),
                                label: const Text(
                                    'Add Missing to Shopping List'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.restaurant),
                                label: Text(
                                    'Almost There ($missingCount missing)'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: const Center(
        child: Icon(Icons.restaurant, size: 80, color: Colors.white38),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _CookNowButton extends StatefulWidget {
  final Recipe recipe;
  final List<PantryItem> pantryItems;
  final String householdId;

  const _CookNowButton({
    required this.recipe,
    required this.pantryItems,
    required this.householdId,
  });

  @override
  State<_CookNowButton> createState() => _CookNowButtonState();
}

class _CookNowButtonState extends State<_CookNowButton> {
  bool _isLoading = false;
  int _servings = 1;
  final CookingService _cookingService = CookingService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Servings selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Servings: ',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              IconButton(
                onPressed: _servings > 1
                    ? () => setState(() => _servings--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline, size: 24),
                color: AppColors.primary,
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  '$_servings',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _servings < 10
                    ? () => setState(() => _servings++)
                    : null,
                icon: const Icon(Icons.add_circle_outline, size: 24),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Cook Now button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleCookNow,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.restaurant),
            label: Text(_isLoading ? 'Estimating...' : 'Cook Now'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCookNow() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Get AI consumption estimates
      final estimates = await _cookingService.estimateConsumption(
        recipe: widget.recipe,
        pantryItems: widget.pantryItems,
        servings: _servings,
      );

      if (!mounted) return;

      // Step 2: Show confirmation dialog
      final editedIngredients = await showDialog<List<dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CookingConfirmationDialog(
          recipeTitle: widget.recipe.title,
          servings: _servings,
          ingredients: estimates,
          onCancel: () => Navigator.pop(ctx),
        ),
      );

      if (editedIngredients == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      // Cast to List<CookedIngredient>
      final confirmedIngredients =
          editedIngredients.cast<CookedIngredient>();

      // Step 3: Apply the confirmed consumption
      await _cookingService.applyCooking(
        householdId: widget.householdId,
        confirmedIngredients: confirmedIngredients,
        recipe: widget.recipe,
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        servings: _servings,
        pantryItems: widget.pantryItems,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.recipe.title} cooked! Pantry updated.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cooking flow failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class ShoppingItemData {
  final String name;
  final double quantity;
  final String unit;
  ShoppingItemData({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}
