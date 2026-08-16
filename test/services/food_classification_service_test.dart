import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/food_classification_service.dart';
import 'package:kooked/models/pantry_item.dart';

void main() {
  group('FoodClassificationService Tests', () {
    late FoodClassificationService service;

    setUp(() {
      service = FoodClassificationService();
    });

    test('Normalizes case, whitespace, and plurals correctly', () {
      expect(FoodClassificationService.normalizeName('TOMATOES'), equals('Tomato'));
      expect(FoodClassificationService.normalizeName('  tomatoes  '), equals('Tomato'));
      expect(FoodClassificationService.normalizeName('onions'), equals('Onion'));
      expect(FoodClassificationService.normalizeName('potatoes'), equals('Potato'));
      expect(FoodClassificationService.normalizeName('biscuits'), equals('Biscuits'));
    });

    test('Classifies Tomato → Produce / Raw', () async {
      final res = await service.classify('Tomato', isOnline: false);
      expect(res.category, equals('Produce'));
      expect(res.type, equals('Raw'));
      expect(res.canonicalName, equals('Tomato'));
    });

    test('Classifies Onion → Produce / Raw', () async {
      final res = await service.classify('Onion', isOnline: false);
      expect(res.category, equals('Produce'));
      expect(res.type, equals('Raw'));
    });

    test('Classifies Bread → Grains & Bread / Packaged', () async {
      final res = await service.classify('Bread', isOnline: false);
      expect(res.category, equals('Grains & Bread'));
      expect(res.type, equals('Packaged'));
    });

    test('Classifies Milk → Dairy / Packaged', () async {
      final res = await service.classify('Milk', isOnline: false);
      expect(res.category, equals('Dairy'));
      expect(res.type, equals('Packaged'));
    });

    test('Classifies Tomato Rice → Leftovers / Leftover', () async {
      final res = await service.classify('Tomato Rice', isOnline: false);
      expect(res.category, equals('Leftovers'));
      expect(res.type, equals('Leftover'));
      expect(res.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Classifies Brinjal Curry → Leftovers / Leftover', () async {
      final res = await service.classify('Brinjal Curry', isOnline: false);
      expect(res.category, equals('Leftovers'));
      expect(res.type, equals('Leftover'));
    });

    test('Classifies Sambar → Leftovers / Leftover', () async {
      final res = await service.classify('Sambar', isOnline: false);
      expect(res.category, equals('Leftovers'));
      expect(res.type, equals('Leftover'));
    });

    test('Classifies Frozen Peas → Frozen / Packaged', () async {
      final res = await service.classify('Frozen Peas', isOnline: false);
      expect(res.category, equals('Frozen'));
      expect(res.type, equals('Packaged'));
    });

    test('Classifies Cooking Oil → Oils & Condiments / Packaged', () async {
      final res = await service.classify('Cooking Oil', isOnline: false);
      expect(res.category, equals('Oils & Condiments'));
      expect(res.type, equals('Packaged'));
    });

    test('Distinguishes Basmati Rice (Packaged) vs Tomato Rice (Leftover)', () async {
      final basmati = await service.classify('Basmati Rice', isOnline: false);
      expect(basmati.category, equals('Grains & Bread'));
      expect(basmati.type, equals('Packaged'));

      final tomatoRice = await service.classify('Tomato Rice', isOnline: false);
      expect(tomatoRice.category, equals('Leftovers'));
      expect(tomatoRice.type, equals('Leftover'));
    });

    test('Marks ambiguous food like Rice or Chicken', () async {
      final res = await service.classify('Rice', isOnline: false);
      expect(res.isAmbiguous, isTrue);
      expect(res.confidence, equals(0.5));
    });

    test('Fallback for completely unknown food item', () async {
      final res = await service.classify('Xyz123UnkownItem', isOnline: false);
      expect(res.category, equals('Other'));
      expect(res.type, equals('Raw'));
      expect(res.source, equals(FoodClassificationSource.fallback));
    });

    test('Finds duplicates matching canonical pantry items', () {
      final pantry = [
        PantryItem(
          id: '1',
          name: 'Tomato',
          category: 'Produce',
          quantity: 2,
          unit: 'pcs',
          type: 'Raw',
          dateAdded: DateTime.now(),
          addedBy: 'user',
          householdId: 'h1',
        ),
      ];

      final match = FoodClassificationService.findDuplicate('tomatoes', pantry);
      expect(match, isNotNull);
      expect(match!.id, equals('1'));
      expect(match.name, equals('Tomato'));
    });
  });
}
