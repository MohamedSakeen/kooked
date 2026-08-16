import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/utils/constants.dart';

void main() {
  group('AppConstants', () {
    test('appName and appTagline are set', () {
      expect(AppConstants.appName, 'KooKed');
      expect(AppConstants.appTagline, isNotEmpty);
    });

    test('pantryCategories is non-empty and contains expected items', () {
      expect(AppConstants.pantryCategories, isNotEmpty);
      expect(AppConstants.pantryCategories.length, greaterThanOrEqualTo(10));
      expect(AppConstants.pantryCategories, contains('Dairy'));
      expect(AppConstants.pantryCategories, contains('Produce'));
      expect(AppConstants.pantryCategories, contains('Meat & Seafood'));
      expect(AppConstants.pantryCategories, contains('Leftovers'));
      expect(AppConstants.pantryCategories, contains('Other'));
    });

    test('itemTypes is non-empty and contains expected items', () {
      expect(AppConstants.itemTypes, isNotEmpty);
      expect(AppConstants.itemTypes, contains('Raw'));
      expect(AppConstants.itemTypes, contains('Packaged'));
      expect(AppConstants.itemTypes, contains('Leftover'));
    });

    test('cuisineTypes is non-empty and contains expected items', () {
      expect(AppConstants.cuisineTypes, isNotEmpty);
      expect(AppConstants.cuisineTypes.length, greaterThanOrEqualTo(10));
      expect(AppConstants.cuisineTypes, contains('Italian'));
      expect(AppConstants.cuisineTypes, contains('Indian'));
      expect(AppConstants.cuisineTypes, contains('Chinese'));
      expect(AppConstants.cuisineTypes, contains('Mexican'));
      expect(AppConstants.cuisineTypes, contains('Japanese'));
    });

    test('difficultyLevels has exactly Easy, Medium, Hard', () {
      expect(AppConstants.difficultyLevels.length, 3);
      expect(AppConstants.difficultyLevels, contains('Easy'));
      expect(AppConstants.difficultyLevels, contains('Medium'));
      expect(AppConstants.difficultyLevels, contains('Hard'));
    });

    test('categoryIcons has an entry for every pantry category', () {
      for (final cat in AppConstants.pantryCategories) {
        expect(AppConstants.categoryIcons.containsKey(cat), isTrue,
            reason: 'Missing icon for category: $cat');
      }
    });
  });
}
