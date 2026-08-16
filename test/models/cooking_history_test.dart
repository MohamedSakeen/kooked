import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/models/cooking_history.dart';

void main() {
  group('CookedIngredient', () {
    test('toMap and fromMap round-trip', () {
      final ingredient = CookedIngredient(
        name: 'Tomatoes',
        quantityConsumed: 2.5,
        unit: 'pcs',
        pantryItemId: 'pantry-123',
      );

      final map = ingredient.toMap();
      expect(map['name'], 'Tomatoes');
      expect(map['quantityConsumed'], 2.5);
      expect(map['unit'], 'pcs');
      expect(map['pantryItemId'], 'pantry-123');

      final restored = CookedIngredient.fromMap(map);
      expect(restored.name, 'Tomatoes');
      expect(restored.quantityConsumed, 2.5);
      expect(restored.unit, 'pcs');
      expect(restored.pantryItemId, 'pantry-123');
    });

    test('fromMap handles missing fields', () {
      final ingredient = CookedIngredient.fromMap({});
      expect(ingredient.name, '');
      expect(ingredient.quantityConsumed, 0.0);
      expect(ingredient.unit, 'pcs');
      expect(ingredient.pantryItemId, null);
    });

    test('handles zero consumption', () {
      final ingredient = CookedIngredient(
        name: 'Salt',
        quantityConsumed: 0,
        unit: 'tsp',
      );
      expect(ingredient.quantityConsumed, 0);
      expect(ingredient.toMap()['quantityConsumed'], 0);
    });
  });

  group('CookingHistory', () {
    test('toMap produces correct output', () {
      final history = CookingHistory(
        id: '',
        recipeId: 'recipe-1',
        recipeName: 'Pasta Primavera',
        cookedBy: 'user-1',
        householdId: 'house-1',
        cookedAt: DateTime(2025, 6, 15),
        ingredients: [
          CookedIngredient(
              name: 'Pasta', quantityConsumed: 200, unit: 'g'),
          CookedIngredient(
              name: 'Sauce', quantityConsumed: 100, unit: 'ml'),
        ],
        servings: 2,
        estimatedMoneySaved: 5.50,
        estimatedCo2Saved: 1.0,
      );

      final map = history.toMap();
      expect(map['recipeId'], 'recipe-1');
      expect(map['recipeName'], 'Pasta Primavera');
      expect(map['cookedBy'], 'user-1');
      expect(map['householdId'], 'house-1');
      expect(map['servings'], 2);
      expect(map['estimatedMoneySaved'], 5.50);
      expect(map['estimatedCo2Saved'], 1.0);
      expect((map['ingredients'] as List).length, 2);
    });

    test('toMap does not include id', () {
      final history = CookingHistory(
        id: 'should-not-appear',
        recipeId: 'r1',
        recipeName: 'Test',
        cookedBy: 'u1',
        householdId: 'h1',
        cookedAt: DateTime.now(),
        ingredients: [],
      );

      final map = history.toMap();
      expect(map.containsKey('id'), false);
    });

    test('defaults for optional fields', () {
      final history = CookingHistory(
        id: '',
        recipeId: 'r1',
        recipeName: 'Test',
        cookedBy: 'u1',
        householdId: 'h1',
        cookedAt: DateTime.now(),
        ingredients: [],
      );

      expect(history.servings, 1);
      expect(history.estimatedMoneySaved, null);
      expect(history.estimatedCo2Saved, null);
    });
  });
}
