import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('defaults has correct values', () {
      final prefs = NotificationPreferences.defaults();
      expect(prefs.expiryAlerts, true);
      expect(prefs.recipeSuggestions, true);
      expect(prefs.shoppingReminders, true);
      expect(prefs.wasteTips, false);
      expect(prefs.cookingReminders, true);
    });

    test('toMap and fromMap round-trip', () {
      final original = NotificationPreferences(
        expiryAlerts: false,
        recipeSuggestions: true,
        shoppingReminders: false,
        wasteTips: true,
        cookingReminders: false,
      );

      final map = original.toMap();
      expect(map['expiryAlerts'], false);
      expect(map['recipeSuggestions'], true);
      expect(map['shoppingReminders'], false);
      expect(map['wasteTips'], true);
      expect(map['cookingReminders'], false);

      final restored = NotificationPreferences.fromMap(map);
      expect(restored.expiryAlerts, false);
      expect(restored.recipeSuggestions, true);
      expect(restored.shoppingReminders, false);
      expect(restored.wasteTips, true);
      expect(restored.cookingReminders, false);
    });

    test('fromMap handles missing fields with defaults', () {
      final prefs = NotificationPreferences.fromMap({});
      expect(prefs.expiryAlerts, true);
      expect(prefs.recipeSuggestions, true);
      expect(prefs.shoppingReminders, true);
      expect(prefs.wasteTips, false);
      expect(prefs.cookingReminders, true);
    });

    test('copyWith modifies only specified fields', () {
      final original = NotificationPreferences.defaults();

      final updated = original.copyWith(wasteTips: true, expiryAlerts: false);
      expect(updated.wasteTips, true);
      expect(updated.expiryAlerts, false);
      expect(updated.recipeSuggestions, true); // unchanged
      expect(updated.shoppingReminders, true); // unchanged
      expect(updated.cookingReminders, true); // unchanged
    });

    test('copyWith preserves all when no args', () {
      final original = NotificationPreferences.defaults();
      final copy = original.copyWith();

      expect(copy.expiryAlerts, original.expiryAlerts);
      expect(copy.recipeSuggestions, original.recipeSuggestions);
      expect(copy.shoppingReminders, original.shoppingReminders);
      expect(copy.wasteTips, original.wasteTips);
      expect(copy.cookingReminders, original.cookingReminders);
    });
  });
}
