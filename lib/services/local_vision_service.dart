import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'food_classification_service.dart';

/// Offline visual food item classifier powered by an on-device ResNet model
/// fine-tuned specifically on produce (fruits and vegetables).
class LocalVisionService {
  Interpreter? _interpreter;
  List<String> _labels;
  final FoodClassificationService _classifier;
  bool _isLoaded = false;
  final double defaultConfidenceThreshold;

  static const String modelAssetPath = 'assets/models/food_classifier.tflite';
  static const String labelsAssetPath = 'assets/models/food_labels.txt';

  LocalVisionService({
    double confidenceThreshold = 0.25,
    FoodClassificationService? classifier,
    Interpreter? interpreter,
    List<String>? labels,
  })  : defaultConfidenceThreshold = confidenceThreshold,
        _classifier = classifier ?? FoodClassificationService(),
        _interpreter = interpreter,
        _labels = labels ?? [],
        _isLoaded = interpreter != null && labels != null && labels.isNotEmpty;

  /// Loads the TFLite model and labels from Flutter assets.
  Future<bool> initialize() async {
    if (_isLoaded) return true;
    if (kIsWeb) return false;

    try {
      if (_interpreter == null) {
        final options = InterpreterOptions()..threads = 2;
        _interpreter = await Interpreter.fromAsset(modelAssetPath, options: options);
      }

      if (_labels.isEmpty) {
        final labelData = await rootBundle.loadString(labelsAssetPath);
        _labels = labelData
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      _isLoaded = _interpreter != null && _labels.isNotEmpty;
      return _isLoaded;
    } catch (e) {
      debugPrint('LocalVisionService initialize error: $e');
      return false;
    }
  }

  /// Analyzes an image file on-device using the produce neural network
  /// and returns identified food items with confidence scores.
  Future<List<Map<String, dynamic>>> analyzeFoodImage(
    File imageFile, {
    double? minConfidence,
  }) async {
    if (kIsWeb) return [];

    try {
      final initialized = await initialize();
      if (!initialized || _interpreter == null || _labels.isEmpty) {
        return [];
      }

      final rawBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(rawBytes);
      if (image == null) return [];

      // Crop central square to preserve natural aspect ratio of produce in portrait photos
      final cropSize = math.min(image.width, image.height);
      final cropX = (image.width - cropSize) ~/ 2;
      final cropY = (image.height - cropSize) ~/ 2;
      final cropped = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropSize,
        height: cropSize,
      );

      // Resize cropped square to model input 224x224
      final resized = img.copyResize(cropped, width: 224, height: 224);

      // Preprocessing: ImageNet normalization
      // mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225]
      const mean = [0.485, 0.456, 0.406];
      const std = [0.229, 0.224, 0.225];

      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              final r = (pixel.r / 255.0 - mean[0]) / std[0];
              final g = (pixel.g / 255.0 - mean[1]) / std[1];
              final b = (pixel.b / 255.0 - mean[2]) / std[2];
              return [r, g, b];
            },
          ),
        ),
      );

      // Prepare output buffer [1, num_classes]
      final output = List.generate(
        1,
        (_) => List<double>.filled(_labels.length, 0.0),
      );

      _interpreter!.run(input, output);

      final rawLogits = output[0];
      final probabilities = _softmax(rawLogits);

      final threshold = minConfidence ?? defaultConfidenceThreshold;

      // Pair each label with its confidence
      final List<_ScoredItem> scoredItems = [];
      for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
        scoredItems.add(_ScoredItem(_labels[i], probabilities[i]));
      }
      scoredItems.sort((a, b) => b.score.compareTo(a.score));

      if (scoredItems.isEmpty) return [];

      final topItem = scoredItems.first;
      if (topItem.score < threshold) {
        return [];
      }

      final List<Map<String, dynamic>> detectedItems = [];
      final Set<String> seenNames = {};

      for (final candidate in scoredItems) {
        if (candidate.score < threshold) break;

        // Keep the top item; for secondary candidates, require significant relative confidence
        if (candidate != topItem) {
          if (candidate.score < 0.30 || candidate.score < topItem.score * 0.4) {
            break;
          }
        }

        final rawName = candidate.name;
        final classResult = await _classifier.classify(rawName, isOnline: false);
        final canonicalName = classResult.canonicalName.isNotEmpty
            ? classResult.canonicalName
            : _capitalize(rawName);

        final lowerKey = canonicalName.toLowerCase();
        if (seenNames.contains(lowerKey)) continue;
        seenNames.add(lowerKey);

        detectedItems.add({
          'name': canonicalName,
          'qty': 1.0,
          'unit': guessUnit(classResult.category),
          'category': classResult.category,
          'type': classResult.type,
          'confirmed': true,
          'confidence': candidate.score,
          'source': 'offline_food_ai',
        });
      }

      return detectedItems;
    } catch (e) {
      debugPrint('LocalVisionService analyzeFoodImage error: $e');
      return [];
    }
  }

  /// Numerically stable softmax computation
  static List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    double maxLogit = logits.reduce((a, b) => a > b ? a : b);
    double sum = 0.0;
    final expVals = List<double>.filled(logits.length, 0.0);

    for (int i = 0; i < logits.length; i++) {
      final expVal = math.exp(logits[i] - maxLogit);
      expVals[i] = expVal;
      sum += expVal;
    }

    if (sum <= 0.0) return List<double>.filled(logits.length, 0.0);
    return expVals.map((e) => e / sum).toList();
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  static String guessUnit(String category) {
    switch (category) {
      case 'Beverages':
      case 'Dairy':
        return 'L';
      case 'Grains & Bread':
      case 'Meat & Seafood':
        return 'kg';
      default:
        return 'pcs';
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}

class _ScoredItem {
  final String name;
  final double score;

  _ScoredItem(this.name, this.score);
}
