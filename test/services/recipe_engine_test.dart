import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/recipe_engine.dart';
import 'package:kooked/models/recipe.dart';
import 'package:kooked/models/pantry_item.dart';

PantryItem _pantryItem(String name, {String? id, DateTime? dateAdded}) {
  return PantryItem(
    id: id ?? 'pantry-${name.hashCode}',
    name: name,
    category: 'Other',
    quantity: 1.0,
    unit: 'pcs',
    type: 'Raw',
    dateAdded: dateAdded ?? DateTime(2025, 6, 1),
    addedBy: 'user-1',
    householdId: 'house-1',
  );
}

Recipe _recipe(String title, List<String> ingredients) {
  return Recipe(
    id: 'recipe-${title.hashCode}',
    title: title,
    ingredients: ingredients
        .map((name) => RecipeIngredient(name: name, quantity: 1, unit: 'pcs'))
        .toList(),
    steps: ['Step 1'],
    cuisine: 'Italian',
    prepTimeMinutes: 5,
    cookTimeMinutes: 10,
    servings: 2,
    difficulty: 'Easy',
    createdAt: DateTime(2025, 6, 1),
  );
}

void main() {
  group('RecipeEngine.matchRecipes', () {
    test('returns Cook Now recipes when all ingredients in pantry', () {
      final pantry = [_pantryItem('Pasta'), _pantryItem('Tomato')];
      final recipes = [_recipe('Pasta Pomodoro', ['Pasta', 'Tomato'])];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: pantry,
      );

      expect(results.length, 1);
      expect(results.first.allInPantry, true);
      expect(results.first.missingCount, 0);
      expect(results.first.matchScore, 1.0);
    });

    test('returns Almost There recipes when 1-3 ingredients missing', () {
      final pantry = [_pantryItem('Pasta')];
      final recipes = [_recipe('Pasta Pomodoro', ['Pasta', 'Tomato', 'Basil'])];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: pantry,
      );

      expect(results.length, 1);
      expect(results.first.allInPantry, false);
      expect(results.first.missingCount, 2);
      expect(results.first.matchScore, closeTo(0.33, 0.01));
    });

    test('filters out recipes missing more than 5 ingredients', () {
      final pantry = [_pantryItem('Pasta')];
      final recipes = [
        _recipe('Complex Dish',
            ['Pasta', 'Tomato', 'Basil', 'Garlic', 'Oil', 'Cheese', 'Pepper']),
      ];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: pantry,
      );

      expect(results.length, 0);
    });

    test('Cook Now recipes sorted before Almost There', () {
      final pantry = [
        _pantryItem('Pasta'),
        _pantryItem('Tomato'),
        _pantryItem('Cheese'),
      ];
      final recipes = [
        _recipe('Simple Pasta', ['Pasta']),
        _recipe('Pasta Pomodoro', ['Pasta', 'Tomato', 'Cheese', 'Basil']),
      ];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: pantry,
      );

      expect(results.length, 2);
      // Simple Pasta is Cook Now (all 1 ingredient available)
      expect(results[0].allInPantry, true);
      // Pasta Pomodoro is Almost There (missing basil)
      expect(results[1].allInPantry, false);
    });

    test('FIFO sorting for Cook Now recipes', () {
      final pantry = [
        _pantryItem('Pasta', dateAdded: DateTime(2025, 6, 10)),
        _pantryItem('Tomato', dateAdded: DateTime(2025, 6, 1)),
      ];
      final recipes = [
        _recipe('Pasta Only', ['Pasta']),
        _recipe('Tomato Salad', ['Tomato']),
      ];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: pantry,
      );

      expect(results.length, 2);
      // Tomato Salad uses the older ingredient (June 1) → comes first
      expect(results[0].recipe.title, 'Tomato Salad');
      expect(results[1].recipe.title, 'Pasta Only');
    });

    test('Almost There recipes sorted by match score descending', () {
      final pantry = [
        _pantryItem('Pasta'),
        _pantryItem('Tomato'),
        _pantryItem('Oil'),
      ];
      final recipes = [
        _recipe('Complex', ['Pasta', 'Tomato', 'Oil', 'Basil', 'Garlic']),
        _recipe('Simple Missing', ['Pasta', 'Tomato', 'Oil', 'Cheese']),
      ];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: pantry,
      );

      expect(results.length, 2);
      // Simple Missing: 3/4 = 0.75
      expect(results[0].recipe.title, 'Simple Missing');
      // Complex: 3/5 = 0.6
      expect(results[1].recipe.title, 'Complex');
    });

    test('case-insensitive ingredient matching', () {
      final pantry = [_pantryItem('pasta'), _pantryItem('TOMATO')];
      final recipes = [_recipe('Mixed Case', ['Pasta', 'Tomato'])];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: pantry,
      );

      expect(results.length, 1);
      expect(results.first.allInPantry, true);
    });

    test('empty pantry returns no Cook Now recipes', () {
      final recipes = [_recipe('Pasta', ['Pasta', 'Sauce'])];

      final results = RecipeEngine.matchRecipes(
        recipes: recipes,
        pantryItems: [],
      );

      // Missing 2 ingredients → should still appear (missingCount <= 5)
      expect(results.length, 1);
      expect(results.first.allInPantry, false);
    });

    test('empty recipes returns empty results', () {
      final pantry = [_pantryItem('Pasta')];
      final results = RecipeEngine.matchRecipes(
        recipes: [],
        pantryItems: pantry,
      );
      expect(results.length, 0);
    });
  });

  group('RecipeEngine.getMissingIngredients', () {
    test('returns missing ingredients', () {
      final pantry = [_pantryItem('Pasta')];
      final recipe = _recipe('Pasta Pomodoro', ['Pasta', 'Tomato', 'Basil']);

      final missing = RecipeEngine.getMissingIngredients(
        recipe: recipe,
        pantryItems: pantry,
      );

      expect(missing.length, 2);
      expect(missing.map((i) => i.name).toSet(), {'Tomato', 'Basil'});
    });

    test('returns empty when all available', () {
      final pantry = [_pantryItem('Pasta'), _pantryItem('Tomato')];
      final recipe = _recipe('Simple', ['Pasta', 'Tomato']);

      final missing = RecipeEngine.getMissingIngredients(
        recipe: recipe,
        pantryItems: pantry,
      );

      expect(missing.length, 0);
    });
  });

  group('RecipeEngine.isCookNow', () {
    test('returns true when all ingredients available', () {
      final pantry = [_pantryItem('Pasta'), _pantryItem('Sauce')];
      final recipe = _recipe('Pasta', ['Pasta', 'Sauce']);

      expect(
        RecipeEngine.isCookNow(recipe: recipe, pantryItems: pantry),
        true,
      );
    });

    test('returns false when ingredients missing', () {
      final pantry = [_pantryItem('Pasta')];
      final recipe = _recipe('Pasta', ['Pasta', 'Sauce']);

      expect(
        RecipeEngine.isCookNow(recipe: recipe, pantryItems: pantry),
        false,
      );
    });

    test('handles empty ingredients list', () {
      final recipe = _recipe('Empty', []);
      expect(
        RecipeEngine.isCookNow(recipe: recipe, pantryItems: []),
        true,
      );
    });
  });
}
