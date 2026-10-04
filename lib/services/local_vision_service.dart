import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'food_classification_service.dart';
import 'produce_label_aliases.dart';
import 'scan_vision_preprocessor.dart';
import 'scan_vision_types.dart';

/// Seam over the TFLite interpreter.
///
/// Production uses [TfliteTensorRunner]; tests supply a deterministic
/// implementation so SUCCESS / EMPTY / FAILED can each be exercised without the
/// native library.
abstract class ScanTensorRunner {
  const ScanTensorRunner();

  void run(List<Object?> input, List<Object?> output);

  void close();
}

/// Wraps a real [Interpreter] as a [ScanTensorRunner].
class TfliteTensorRunner implements ScanTensorRunner {
  TfliteTensorRunner(this._interpreter);

  final Interpreter _interpreter;

  @override
  void run(List<Object?> input, List<Object?> output) {
    _interpreter.run(input, output);
  }

  @override
  void close() => _interpreter.close();
}

/// Offline visual food item classifier powered by an on-device ResNet model
/// fine-tuned specifically on produce (fruits and vegetables).
///
/// Reports one of three typed outcomes — success, empty, failed — so a model
/// that ran correctly but rejected its own output is never mistaken for an
/// engine failure.
class LocalVisionService {
  ScanTensorRunner? _runner;
  List<String> _labels;
  final FoodClassificationService _classifier;
  bool _isLoaded = false;
  ScanVisionFailure? _initializationFailure;

  /// Number of leading classes reported in diagnostics.
  static const int diagnosticTopK = 5;

  final double defaultConfidenceThreshold;

  /// Calibrated confidence floor.
  ///
  /// Measured against 10 raw-produce photographs the model classifies correctly
  /// (all at confidence >= 0.9333 under production preprocessing) and 39
  /// out-of-domain prepared-dish photographs. Accepting all 10 while rejecting
  /// 37 of the 39 is the best separation the data supports; every value from
  /// 0.85 to 0.90 produces that same outcome, so the operating point sits inside
  /// a plateau rather than on an edge.
  ///
  /// A single gate is sufficient. A margin-over-top-2 gate was evaluated and
  /// deliberately omitted: because probabilities sum to 1, the smallest margin
  /// reachable at a top-1 confidence of [calibratedMinConfidence] is
  /// `2 * 0.85 - 1 = 0.70`, so any margin floor below 0.70 — including every
  /// value that separates the two measured populations — is unreachable and can
  /// never fire. Nor is it needed: a model undecided between two near-synonym
  /// classes such as `bell pepper` and `capsicum` necessarily spreads its mass
  /// across both, which puts top-1 near 0.47 and is rejected here regardless.
  ///
  /// Derived from a proxy negative set. Re-calibrate once real camera frames
  /// containing no produce are available.
  static const double calibratedMinConfidence = 0.85;

  static const String modelAssetPath = 'assets/models/food_classifier.tflite';
  static const String labelsAssetPath = 'assets/models/food_labels.txt';

  LocalVisionService({
    double confidenceThreshold = calibratedMinConfidence,
    FoodClassificationService? classifier,
    ScanTensorRunner? runner,
    List<String>? labels,
  })  : defaultConfidenceThreshold = confidenceThreshold,
        _classifier = classifier ?? FoodClassificationService(),
        _runner = runner,
        _labels = labels ?? [],
        _isLoaded = runner != null && labels != null && labels.isNotEmpty;

  /// Reason the last [initialize] call failed, or `null` if it succeeded.
  ScanVisionFailure? get initializationFailure => _initializationFailure;

  /// Loads the TFLite model and labels from Flutter assets.
  Future<bool> initialize() async {
    if (_isLoaded) return true;
    if (kIsWeb) {
      _initializationFailure = const ScanVisionFailure(
        stage: ScanVisionStage.unsupportedPlatform,
        reason: 'On-device inference is not supported on web',
      );
      return false;
    }

    try {
      if (_runner == null) {
        final options = InterpreterOptions()..threads = 2;
        _runner = TfliteTensorRunner(
          await Interpreter.fromAsset(modelAssetPath, options: options),
        );
      }

      if (_labels.isEmpty) {
        final labelData = await rootBundle.loadString(labelsAssetPath);
        _labels = labelData
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (_labels.isEmpty) {
        _initializationFailure = const ScanVisionFailure(
          stage: ScanVisionStage.initialization,
          reason: 'Label asset $labelsAssetPath contained no labels',
        );
        _isLoaded = false;
        return false;
      }

      _isLoaded = true;
      _initializationFailure = null;
      return true;
    } on Object catch (error) {
      _initializationFailure = ScanVisionFailure(
        stage: ScanVisionStage.initialization,
        reason: 'Could not initialize on-device model: $error',
        cause: error,
      );
      _isLoaded = false;
      if (kDebugMode) {
        debugPrint('[LocalVisionService] initialize failed: $error');
      }
      return false;
    }
  }

  /// Runs on-device inference and reports a typed outcome.
  ///
  /// - [ScanVisionStatus.success]: at least one prediction cleared the gates.
  /// - [ScanVisionStatus.empty]: inference ran; confidence logic rejected all.
  /// - [ScanVisionStatus.failed]: the model could not be initialized, the image
  ///   could not be read or decoded, or execution threw.
  Future<ScanVisionResult> analyzeFoodImage(
    File imageFile, {
    double? minConfidence,
  }) async {
    if (kIsWeb) {
      return ScanVisionResult.failed(
        source: ScanModelSource.local,
        failure: const ScanVisionFailure(
          stage: ScanVisionStage.unsupportedPlatform,
          reason: 'On-device inference is not supported on web',
        ),
      );
    }

    if (!await initialize() || _runner == null || _labels.isEmpty) {
      return ScanVisionResult.failed(
        source: ScanModelSource.local,
        failure: _initializationFailure ??
            const ScanVisionFailure(
              stage: ScanVisionStage.initialization,
              reason: 'Model or labels unavailable',
            ),
      );
    }

    final Stopwatch stopwatch = Stopwatch()..start();

    ScanVisionPreprocessResult prepared;
    try {
      prepared = await ScanVisionPreprocessor.fromFile(imageFile);
    } on Object catch (error) {
      stopwatch.stop();
      final failure = ScanVisionFailure(
        stage: ScanVisionStage.decode,
        reason: 'Could not read or decode image ${imageFile.path}: $error',
        cause: error,
      );
      return ScanVisionResult.failed(
        source: ScanModelSource.local,
        failure: failure,
        diagnostics: _baseDiagnostics(preparedFailure: failure, elapsed: stopwatch.elapsed),
      );
    }

    final output = <List<double>>[
      List<double>.filled(_labels.length, 0.0),
    ];

    try {
      _runner!.run(prepared.tensor, output);
    } on Object catch (error) {
      stopwatch.stop();
      final failure = ScanVisionFailure(
        stage: ScanVisionStage.execution,
        reason: 'Model execution failed: $error',
        cause: error,
      );
      return ScanVisionResult.failed(
        source: ScanModelSource.local,
        failure: failure,
        diagnostics: _baseDiagnostics(
          prepared: prepared,
          preparedFailure: failure,
          elapsed: stopwatch.elapsed,
        ),
      );
    }

    final rawLogits = output.first;
    if (rawLogits.length != _labels.length) {
      stopwatch.stop();
      final failure = ScanVisionFailure(
        stage: ScanVisionStage.execution,
        reason: 'Model returned ${rawLogits.length} scores but '
            '${_labels.length} labels are loaded',
      );
      return ScanVisionResult.failed(
        source: ScanModelSource.local,
        failure: failure,
        diagnostics: _baseDiagnostics(
          prepared: prepared,
          preparedFailure: failure,
          elapsed: stopwatch.elapsed,
        ),
      );
    }

    final probabilities = _softmax(rawLogits);
    final threshold = minConfidence ?? defaultConfidenceThreshold;

    final List<_ScoredItem> scoredItems = <_ScoredItem>[];
    for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
      scoredItems.add(_ScoredItem(i, _labels[i], probabilities[i]));
    }
    scoredItems.sort((a, b) => b.score.compareTo(a.score));

    stopwatch.stop();

    if (scoredItems.isEmpty) {
      return ScanVisionResult.empty(
        source: ScanModelSource.local,
        diagnostics: _baseDiagnostics(prepared: prepared, elapsed: stopwatch.elapsed),
      );
    }

    final ranked = scoredItems.take(diagnosticTopK).toList();

    ScanVisionDiagnostics diagnosticsWithScores(
      ScanVisionFailure? failure, {
      String? rejectionReason,
    }) {
      return _baseDiagnostics(
        prepared: prepared,
        elapsed: stopwatch.elapsed,
        ranked: ranked,
        failure: failure,
        rejectionReason: rejectionReason,
      );
    }

    final topItem = scoredItems.first;

    if (topItem.score < threshold) {
      return ScanVisionResult.empty(
        source: ScanModelSource.local,
        diagnostics: diagnosticsWithScores(
          null,
          rejectionReason:
              'confidence ${_fmt(topItem.score)} below floor ${_fmt(threshold)}',
        ),
      );
    }

    final List<Map<String, dynamic>> detectedItems = <Map<String, dynamic>>[];
    final Set<String> seenNames = <String>{};

    for (final candidate in scoredItems) {
      if (candidate.score < threshold) break;

      // Keep the top item; for secondary candidates, require significant relative confidence
      if (candidate != topItem) {
        if (candidate.score < 0.30 || candidate.score < topItem.score * 0.4) {
          break;
        }
      }

      final rawName = ProduceLabelAliases.canonicalize(candidate.name);
      final classResult = await _classifier.classify(rawName, isOnline: false);
      final canonicalName = classResult.canonicalName.isNotEmpty
          ? classResult.canonicalName
          : _capitalize(rawName);

      final lowerKey = canonicalName.toLowerCase();
      if (seenNames.contains(lowerKey)) continue;
      seenNames.add(lowerKey);

      detectedItems.add(<String, dynamic>{
        'name': canonicalName,
        'qty': 1.0,
        'unit': guessUnit(classResult.category),
        'category': classResult.category,
        'type': classResult.type,
        'confirmed': true,
        'confidence': candidate.score,
        'source': 'offline_food_ai',
        'modelSource': ScanModelSource.local.name,
      });
    }

    final diagnostics = diagnosticsWithScores(null);

    if (detectedItems.isEmpty) {
      return ScanVisionResult.empty(
        source: ScanModelSource.local,
        diagnostics: diagnostics,
      );
    }

    return ScanVisionResult.success(
      source: ScanModelSource.local,
      items: detectedItems,
      diagnostics: diagnostics,
    );
  }

  ScanVisionDiagnostics _baseDiagnostics({
    ScanVisionPreprocessResult? prepared,
    ScanVisionFailure? preparedFailure,
    Duration? elapsed,
    List<_ScoredItem>? ranked,
    ScanVisionFailure? failure,
    String? rejectionReason,
  }) {
    final diagnostics = ScanVisionDiagnostics(
      source: ScanModelSource.local,
      imageWidth: prepared?.imageWidth,
      imageHeight: prepared?.imageHeight,
      cropX: prepared?.cropX,
      cropY: prepared?.cropY,
      cropWidth: prepared?.cropWidth,
      cropHeight: prepared?.cropHeight,
      resizeWidth: prepared?.resizeWidth ?? ScanVisionPreprocessor.inputSize,
      resizeHeight: prepared?.resizeHeight ?? ScanVisionPreprocessor.inputSize,
      interpolation:
          prepared?.interpolation ?? ScanVisionPreprocessor.resizeInterpolation,
      tensorShape: ScanVisionPreprocessor.tensorShape,
      tensorDtype: ScanVisionPreprocessor.tensorDtype,
      normalizationMean: ScanVisionPreprocessor.normalizationMean,
      normalizationStd: ScanVisionPreprocessor.normalizationStd,
      topIndices: ranked?.map((e) => e.index).toList() ?? const <int>[],
      topLabels: ranked?.map((e) => e.name).toList() ?? const <String>[],
      topConfidences:
          ranked?.map((e) => e.score).toList() ?? const <double>[],
      inferenceDuration: elapsed,
      failure: failure ?? preparedFailure,
      rejectionReason: rejectionReason,
    );

    if (kDebugMode) {
      debugPrint('[LocalVisionService] ${diagnostics.describe()}');
    }

    return diagnostics;
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

  static String _fmt(double value) => value.toStringAsFixed(4);

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
    _runner?.close();
    _runner = null;
    _isLoaded = false;
  }
}

class _ScoredItem {
  final int index;
  final String name;
  final double score;

  _ScoredItem(this.index, this.name, this.score);
}