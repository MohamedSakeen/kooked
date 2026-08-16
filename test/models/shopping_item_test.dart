import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/models/shopping_item.dart';

void main() {
  group('ShoppingItem', () {
    test('toMap produces correct output', () {
      final item = ShoppingItem(
        id: 'shop-1',
        name: 'Milk',
        quantity: 2.0,
        unit: 'L',
        isChecked: false,
        householdId: 'house-1',
      );

      final map = item.toMap();
      expect(map['name'], 'Milk');
      expect(map['quantity'], 2.0);
      expect(map['unit'], 'L');
      expect(map['isChecked'], false);
      expect(map['householdId'], 'house-1');
    });

    test('toMap does not include id', () {
      final item = ShoppingItem(
        id: 'should-not-appear',
        name: 'Test',
        quantity: 1,
        unit: 'pcs',
        householdId: 'h1',
      );

      final map = item.toMap();
      expect(map.containsKey('id'), false);
    });

    test('copyWith creates modified copy', () {
      final item = ShoppingItem(
        id: 'shop-1',
        name: 'Milk',
        quantity: 2.0,
        unit: 'L',
        isChecked: false,
        householdId: 'house-1',
      );

      final updated = item.copyWith(isChecked: true, quantity: 3.0);
      expect(updated.isChecked, true);
      expect(updated.quantity, 3.0);
      expect(updated.name, 'Milk'); // unchanged
      expect(updated.id, 'shop-1'); // unchanged
      expect(updated.householdId, 'house-1'); // unchanged
    });

    test('defaults', () {
      final item = ShoppingItem(
        id: '',
        name: 'Item',
        quantity: 1,
        unit: 'pcs',
        householdId: 'h1',
      );

      expect(item.isChecked, false);
      expect(item.addedFromRecipeId, null);
    });

    test('toMap includes addedFromRecipeId when set', () {
      final item = ShoppingItem(
        id: 'shop-1',
        name: 'Bread',
        quantity: 1,
        unit: 'pcs',
        addedFromRecipeId: 'recipe-42',
        householdId: 'h1',
      );

      final map = item.toMap();
      expect(map['addedFromRecipeId'], 'recipe-42');
    });

    test('toMap includes addedFromRecipeId as null when not set', () {
      final item = ShoppingItem(
        id: 'shop-1',
        name: 'Bread',
        quantity: 1,
        unit: 'pcs',
        householdId: 'h1',
      );

      final map = item.toMap();
      expect(map.containsKey('addedFromRecipeId'), true);
      expect(map['addedFromRecipeId'], null);
    });
  });
}
