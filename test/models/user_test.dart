import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/models/user.dart';

void main() {
  group('AppUser', () {
    test('toMap produces correct output', () {
      final user = AppUser(
        uid: 'uid-1',
        name: 'John',
        email: 'john@example.com',
        householdId: 'house-1',
        createdAt: DateTime(2025, 6, 15),
        photoUrl: 'https://example.com/photo.jpg',
      );

      final map = user.toMap();
      expect(map['uid'], 'uid-1');
      expect(map['name'], 'John');
      expect(map['email'], 'john@example.com');
      expect(map['householdId'], 'house-1');
      expect(map['photoUrl'], 'https://example.com/photo.jpg');
    });

    test('toMap does not include uid', () {
      final user = AppUser(
        uid: 'should-not-appear',
        name: 'Test',
        email: 'test@test.com',
        createdAt: DateTime.now(),
      );

      final map = user.toMap();
      expect(map.containsKey('uid'), false);
    });

    test('copyWith creates modified copy', () {
      final user = AppUser(
        uid: 'uid-1',
        name: 'John',
        email: 'john@example.com',
        createdAt: DateTime(2025, 6, 15),
      );

      final updated = user.copyWith(name: 'Jane', householdId: 'house-2');
      expect(updated.name, 'Jane');
      expect(updated.householdId, 'house-2');
      expect(updated.email, 'john@example.com'); // unchanged
      expect(updated.uid, 'uid-1'); // unchanged
    });

    test('defaults for optional fields', () {
      final user = AppUser(
        uid: 'uid-1',
        name: 'Test',
        email: 'test@test.com',
        createdAt: DateTime.now(),
      );

      expect(user.householdId, null);
      expect(user.photoUrl, null);
    });
  });
}
