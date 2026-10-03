import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/local_vision_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalVisionService Tests', () {
    test('Correctly guesses unit based on category', () {
      expect(LocalVisionService.guessUnit('Dairy'), equals('L'));
      expect(LocalVisionService.guessUnit('Beverages'), equals('L'));
      expect(LocalVisionService.guessUnit('Meat & Seafood'), equals('kg'));
      expect(LocalVisionService.guessUnit('Grains & Bread'), equals('kg'));
      expect(LocalVisionService.guessUnit('Produce'), equals('pcs'));
      expect(LocalVisionService.guessUnit('Snacks'), equals('pcs'));
    });

    test('Food labels file exists and contains only valid produce items', () {
      final labelsFile = File('assets/models/food_labels.txt');
      expect(labelsFile.existsSync(), isTrue, reason: 'food_labels.txt should exist in assets/models');

      final lines = labelsFile
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(lines.length, equals(36), reason: 'Should have exactly 36 produce classes');

      // Verify known items are present
      expect(lines.contains('apple'), isTrue);
      expect(lines.contains('banana'), isTrue);
      expect(lines.contains('tomato'), isTrue);
      expect(lines.contains('capsicum'), isTrue);
      expect(lines.contains('bell pepper'), isTrue);
      expect(lines.contains('potato'), isTrue);
      expect(lines.contains('carrot'), isTrue);
      expect(lines.contains('garlic'), isTrue);
      expect(lines.contains('onion'), isTrue);

      // Verify non-food hallucinated items do NOT exist
      expect(lines.contains('jean'), isFalse);
      expect(lines.contains('jeans'), isFalse);
      expect(lines.contains('cookie'), isFalse);
      expect(lines.contains('tableware'), isFalse);
      expect(lines.contains('furniture'), isFalse);
    });

    test('TFLite produce model asset exists', () {
      final modelFile = File('assets/models/food_classifier.tflite');
      expect(modelFile.existsSync(), isTrue, reason: 'food_classifier.tflite should exist in assets/models');
      expect(modelFile.lengthSync(), greaterThan(10000000), reason: 'Model size should be ~47 MB');
    });

    test('LocalVisionService instantiates cleanly and handles uninitialized state gracefully', () async {
      final service = LocalVisionService();
      // On non-initialized or non-existent file, it returns empty list without throwing
      final results = await service.analyzeFoodImage(File('non_existent.jpg'));
      expect(results, isEmpty);
      service.dispose();
    });
  });
}
