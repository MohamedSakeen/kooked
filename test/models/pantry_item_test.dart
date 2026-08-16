import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/models/pantry_item.dart';

void main() {
  group('PantryItem', () {
    test('toMap produces correct output', () {
      final item = PantryItem(
        id: 'test-id',
        name: 'Tomatoes',
        category: 'Produce',
        quantity: 3.0,
        unit: 'pcs',
        type: 'Raw',
        dateAdded: DateTime(2025, 1, 15),
        addedBy: 'user-123',
        householdId: 'house-456',
      );

      final map = item.toMap();
      expect(map['name'], 'Tomatoes');
      expect(map['category'], 'Produce');
      expect(map['quantity'], 3.0);
      expect(map['unit'], 'pcs');
      expect(map['type'], 'Raw');
      expect(map['addedBy'], 'user-123');
      expect(map['householdId'], 'house-456');
    });

    test('copyWith creates modified copy', () {
      final item = PantryItem(
        id: 'test-id',
        name: 'Tomatoes',
        category: 'Produce',
        quantity: 3.0,
        unit: 'pcs',
        type: 'Raw',
        dateAdded: DateTime(2025, 1, 15),
        addedBy: 'user-123',
        householdId: 'house-456',
      );

      final updated = item.copyWith(quantity: 5.0, unit: 'kg');
      expect(updated.quantity, 5.0);
      expect(updated.unit, 'kg');
      expect(updated.name, 'Tomatoes'); // unchanged
      expect(updated.id, 'test-id'); // unchanged
    });

    test('copyWith preserves original when no args', () {
      final item = PantryItem(
        id: 'test-id',
        name: 'Tomatoes',
        category: 'Produce',
        quantity: 3.0,
        unit: 'pcs',
        type: 'Raw',
        dateAdded: DateTime(2025, 1, 15),
        addedBy: 'user-123',
        householdId: 'house-456',
      );

      final copy = item.copyWith();
      expect(copy.name, item.name);
      expect(copy.quantity, item.quantity);
      expect(copy.unit, item.unit);
      expect(copy.id, item.id);
    });

    test('toMap does not include id (Firestore manages it)', () {
      final item = PantryItem(
        id: 'should-not-be-in-map',
        name: 'Test',
        category: 'Other',
        quantity: 1.0,
        unit: 'pcs',
        type: 'Raw',
        dateAdded: DateTime.now(),
        addedBy: '',
        householdId: '',
      );

      final map = item.toMap();
      expect(map.containsKey('id'), false);
    });

    test('handles zero and fractional quantities', () {
      final item = PantryItem(
        id: 'id',
        name: 'Milk',
        category: 'Dairy',
        quantity: 0.5,
        unit: 'L',
        type: 'Packaged',
        dateAdded: DateTime.now(),
        addedBy: '',
        householdId: '',
      );

      expect(item.quantity, 0.5);
      expect(item.toMap()['quantity'], 0.5);
    });
  });
}
