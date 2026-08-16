import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/models/recipe.dart';

void main() {
  group('RecipeIngredient', () {
    test('toMap and fromMap round-trip', () {
      final ingredient = RecipeIngredient(
        name: 'Tomatoes',
        quantity: 3.0,
        unit: 'pcs',
        inPantry: true,
      );

      final map = ingredient.toMap();
      expect(map['name'], 'Tomatoes');
      expect(map['quantity'], 3.0);
      expect(map['unit'], 'pcs');
      expect(map['inPantry'], true);

      final restored = RecipeIngredient.fromMap(map);
      expect(restored.name, 'Tomatoes');
      expect(restored.quantity, 3.0);
      expect(restored.unit, 'pcs');
      expect(restored.inPantry, true);
    });

    test('fromMap handles missing fields gracefully', () {
      final ingredient = RecipeIngredient.fromMap({});
      expect(ingredient.name, '');
      expect(ingredient.quantity, 0.0);
      expect(ingredient.unit, '');
      expect(ingredient.inPantry, false);
    });
  });

  group('Recipe', () {
    test('totalTimeMinutes computes correctly', () {
      final recipe = Recipe(
        id: '1',
        title: 'Test Recipe',
        ingredients: [],
        steps: ['Step 1'],
        cuisine: 'Italian',
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        servings: 4,
        difficulty: 'Easy',
        createdAt: DateTime.now(),
      );

      expect(recipe.totalTimeMinutes, 30);
    });

    test('toMap produces correct output', () {
      final recipe = Recipe(
        id: '1',
        title: 'Pasta',
        ingredients: [
          RecipeIngredient(name: 'Pasta', quantity: 200, unit: 'g'),
          RecipeIngredient(name: 'Sauce', quantity: 100, unit: 'ml'),
        ],
        steps: ['Boil pasta', 'Add sauce'],
        cuisine: 'Italian',
        prepTimeMinutes: 5,
        cookTimeMinutes: 15,
        servings: 2,
        difficulty: 'Easy',
        isAiGenerated: true,
        createdAt: DateTime(2025, 6, 1),
      );

      final map = recipe.toMap();
      expect(map['title'], 'Pasta');
      expect(map['cuisine'], 'Italian');
      expect(map['prepTimeMinutes'], 5);
      expect(map['cookTimeMinutes'], 15);
      expect(map['servings'], 2);
      expect(map['difficulty'], 'Easy');
      expect(map['isAiGenerated'], true);
      expect((map['ingredients'] as List).length, 2);
      expect((map['steps'] as List).length, 2);
    });

    test('allIngredientsInPantry checks all ingredients', () {
      final recipeAll = Recipe(
        id: '1',
        title: 'All',
        ingredients: [
          RecipeIngredient(name: 'A', quantity: 1, unit: 'g', inPantry: true),
          RecipeIngredient(name: 'B', quantity: 1, unit: 'g', inPantry: true),
        ],
        steps: [],
        cuisine: 'Other',
        prepTimeMinutes: 0,
        cookTimeMinutes: 0,
        servings: 1,
        difficulty: 'Easy',
        createdAt: DateTime.now(),
      );
      expect(recipeAll.allIngredientsInPantry, true);

      final recipeSome = Recipe(
        id: '2',
        title: 'Some',
        ingredients: [
          RecipeIngredient(name: 'A', quantity: 1, unit: 'g', inPantry: true),
          RecipeIngredient(name: 'B', quantity: 1, unit: 'g', inPantry: false),
        ],
        steps: [],
        cuisine: 'Other',
        prepTimeMinutes: 0,
        cookTimeMinutes: 0,
        servings: 1,
        difficulty: 'Easy',
        createdAt: DateTime.now(),
      );
      expect(recipeSome.allIngredientsInPantry, false);
    });

    test('missingIngredientCount works correctly', () {
      final recipe = Recipe(
        id: '1',
        title: 'Test',
        ingredients: [
          RecipeIngredient(name: 'A', quantity: 1, unit: 'g', inPantry: true),
          RecipeIngredient(name: 'B', quantity: 1, unit: 'g', inPantry: false),
          RecipeIngredient(name: 'C', quantity: 1, unit: 'g', inPantry: false),
        ],
        steps: [],
        cuisine: 'Other',
        prepTimeMinutes: 0,
        cookTimeMinutes: 0,
        servings: 1,
        difficulty: 'Easy',
        createdAt: DateTime.now(),
      );
      expect(recipe.missingIngredientCount, 2);
    });

    test('empty ingredients and steps do not throw', () {
      final recipe = Recipe(
        id: '1',
        title: 'Minimal',
        ingredients: [],
        steps: [],
        cuisine: 'Other',
        prepTimeMinutes: 0,
        cookTimeMinutes: 0,
        servings: 1,
        difficulty: 'Easy',
        createdAt: DateTime.now(),
      );

      expect(recipe.title, 'Minimal');
      expect(recipe.ingredients.length, 0);
      expect(recipe.steps.length, 0);
      expect(recipe.totalTimeMinutes, 0);
      expect(recipe.allIngredientsInPantry, true);
      expect(recipe.missingIngredientCount, 0);
    });
  });
}
