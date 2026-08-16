import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/theme.dart';
import '../../utils/constants.dart';
import '../../services/firestore_service.dart';
import '../../services/recipe_engine.dart';
import '../../models/recipe.dart';
import '../../models/pantry_item.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/empty_state.dart';

import '../../services/api_service.dart';
import '../../utils/seed_data.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _firestore = FirestoreService();
  String _selectedCuisine = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isGenerating = false;

  Future<void> _generateAiRecipe(List<PantryItem> pantryItems) async {
    if (pantryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some pantry items first!')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final ingredients = pantryItems
          .map((i) => {
                'name': i.name,
                'quantity': i.quantity,
                'unit': i.unit,
                'type': i.type,
              })
          .toList();

      final recipeData = await ApiService().generateRecipe(
        availableIngredients: ingredients,
      );

      final newRecipe = Recipe(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        title: recipeData['title'] ?? 'Generated Recipe',
        ingredients: (recipeData['ingredients'] as List<dynamic>?)
                ?.map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        steps: (recipeData['steps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        cuisine: recipeData['cuisine'] ?? 'Fusion',
        prepTimeMinutes: recipeData['prepTimeMinutes'] ?? 10,
        cookTimeMinutes: recipeData['cookTimeMinutes'] ?? 15,
        servings: recipeData['servings'] ?? 2,
        difficulty: recipeData['difficulty'] ?? 'Easy',
        isAiGenerated: true,
        createdAt: DateTime.now(),
      );

      await FirestoreService().addRecipe(newRecipe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated: ${newRecipe.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate recipe: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<Recipe>>(
        stream: _firestore.recipesStream(),
        builder: (context, recipeSnap) {
          if (recipeSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final fetched = recipeSnap.data ?? [];
          final recipes = fetched.isEmpty ? sampleRecipes : fetched;

          if (recipes.isEmpty) {
            return EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No recipes yet',
              subtitle: 'Add pantry items and recipes will appear here',
            );
          }

          // Get pantry items for matching
          final householdId =
              FirebaseAuth.instance.currentUser?.uid ?? 'demo';

          return StreamBuilder<List<PantryItem>>(
            stream: _firestore.pantryStream(householdId),
            builder: (context, pantrySnap) {
              final pantryItems = pantrySnap.data ?? [];
              final matched = RecipeEngine.matchRecipes(
                recipes: recipes,
                pantryItems: pantryItems,
              );

              // Apply filters
              final filtered = matched.where((m) {
                final matchCuisine = _selectedCuisine == 'All' ||
                    m.recipe.cuisine == _selectedCuisine;
                final matchSearch = _searchQuery.isEmpty ||
                    m.recipe.title
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                return matchCuisine && matchSearch;
              }).toList();

              return Scaffold(
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search recipes...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: [
                          _buildFilterChip('All'),
                          ...AppConstants.cuisineTypes.map(
                            (c) => _buildFilterChip(c),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text('${filtered.length} recipes',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: filtered.isEmpty
                          ? EmptyState(
                              icon: Icons.restaurant_menu,
                              title: 'No recipes found',
                              subtitle:
                                  'Try adjusting your filters or generate one from leftover ingredients',
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 0, 10, 80),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final m = filtered[index];
                                return RecipeCard(
                                  title: m.recipe.title,
                                  cuisine: m.recipe.cuisine,
                                  totalTimeMinutes: m.recipe.totalTimeMinutes,
                                  difficulty: m.recipe.difficulty,
                                  imageUrl: m.recipe.imageUrl,
                                  isAiGenerated: m.recipe.isAiGenerated,
                                  allInPantry: m.allInPantry,
                                  missingCount: m.missingCount,
                                  onTap: () => context.push(
                                      '/recipe/${m.recipe.id}'),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: _isGenerating
                      ? null
                      : () => _generateAiRecipe(pantryItems),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate from Pantry'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final selected = label == _selectedCuisine;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCuisine = label),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}
