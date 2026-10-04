import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:kooked/services/detector_preprocessor.dart';
import 'package:kooked/services/food_classification_service.dart';
import 'package:kooked/services/local_vision_service.dart';
import 'package:kooked/services/produce_label_aliases.dart';
import 'package:kooked/services/scan_vision_types.dart';
import 'package:tflite_flutter/tflite_flutter.dart' show Interpreter;

/// On-device produce **detector** (YOLO26n, 31 classes) that returns one box
/// per item, so a single frame can be counted and localized.
///
/// Complements [LocalVisionService], which is a whole-frame classifier and can
/// only ever name the single most dominant item. Neither replaces the other:
/// the detector supplies counts and geometry, the classifier stays as the
/// validated fallback for classes the detector is not trusted on.
///
/// ### Output contract
///
/// Verified against the exported graph rather than assumed:
///
/// * Input `[1][3][640][640]` float32, RGB, `/255.0`, no mean/std.
/// * Output `[1][35][8400]` float32, channel-major. The 35 channels are 4 box
///   channels followed by 31 class channels.
/// * Class channels are already sigmoid-activated, so scores arrive in 0..1.
/// * Box channels are **normalized 0..1** `cx, cy, w, h` relative to the
///   letterboxed 640 input, not pixels. Treating them as pixels silently
///   collapses every box to a 1x1 corner pixel.
/// * Non-maximum suppression is not folded into the graph.
class ProduceDetectorService {
  ProduceDetectorService({
    ScanTensorRunner? runner,
    FoodClassificationService? classifier,
    List<String>? labels,
    this.minConfidence = defaultMinConfidence,
    this.maxDetections = defaultMaxDetections,
    this.nmsIouThreshold = defaultNmsIouThreshold,
  })  : _runner = runner,
        _classifier = classifier ?? FoodClassificationService(),
        _labels = labels ?? const <String>[],
        _isLoaded = runner != null && labels != null && labels.isNotEmpty;

  /// Path of the packaged detector graph.
  static const String modelAssetPath = 'assets/models/produce_detector.tflite';

  /// Path of the detector's label list, in detector index order.
  static const String labelsAssetPath =
      'assets/models/produce_detector_labels.txt';

  /// Anchor count emitted by the 640x640 export (80x80 + 40x40 + 20x20 grids).
  static const int anchorCount = 8400;

  /// 4 box channels + 31 class channels.
  static const int outputChannels = 35;
  static const int boxChannelCount = 4;

  /// Detector index must be < [classCount] and output channels must match.
  static const int classCount = 31;

  static const int inputSize = DetectorPreprocessor.inputSize;

  /// Number of detections surfaced, highest confidence first.
  static const int defaultMaxDetections = 12;

  /// Confidence floor applied to classes the detector is trusted on.
  static const double defaultMinConfidence = 0.25;

  /// IoU above which same-class boxes are suppressed.
  static const double defaultNmsIouThreshold = 0.45;

  /// Minimum measured AP50 for a class to count as trusted.
  ///
  /// Chosen to separate the classes the held-out split can actually support
  /// from the ones where the model is effectively guessing.
  static const double trustedMinAp50 = 0.40;

  /// Raised confidence floor for classes below [trustedMinAp50].
  ///
  /// Rather than dropping the 19 untrusted classes outright — which would hide
  /// most of the vocabulary — the detector demands much stronger evidence
  /// before reporting them and flags the result so the UI can qualify it.
  static const double lowReliabilityMinConfidence = 0.60;

  /// Held-out test AP50 per class, from the validated export.
  ///
  /// A `null` entry means the split contained no instances of that class, so
  /// the model's ability there is genuinely unknown rather than known-good.
  static const Map<String, double?> measuredAp50 = <String, double?>{
    'apple': 0.571,
    'banana': 0.852,
    'Capsicum': 0.266,
    'carrot': 0.542,
    'cauliflower': 0.337,
    'Corn': 0.164,
    'cucumber': 0.298,
    'eggplant': 0.0,
    'garlic': 0.004,
    'ginger': 0.0,
    'grapes': 0.318,
    'kiwi': 0.529,
    'lemon': 0.205,
    'lettuce': 0.168,
    'onion': 0.304,
    'orange': 0.624,
    'pear': 0.046,
    'peas': 0.003,
    'pineapple': 0.004,
    'potato': null,
    'raddish': 0.305,
    'sweetpotato': 0.109,
    'tomato': 0.683,
    'turnip': null,
    'watermelon': null,
    'beetroot': 0.896,
    'cabbage': 0.892,
    'mango': 0.769,
    'pomegranate': 0.912,
    'soy beans': 0.700,
    'spinach': 0.881,
  };

  /// Classes that cleared [trustedMinAp50] on the held-out split.
  static Set<String> get trustedClasses => <String>{
        for (final entry in measuredAp50.entries)
          if ((entry.value ?? 0.0) >= trustedMinAp50) entry.key,
      };

  /// Confidence floor actually applied to [name].
  static double confidenceFloorFor(String name) =>
      isTrusted(name) ? defaultMinConfidence : lowReliabilityMinConfidence;

  /// Whether the held-out split supports reporting [name] at the normal floor.
  static bool isTrusted(String name) {
    final ap = measuredAp50[ProduceLabelAliases.canonicalize(name)];
    return ap != null && ap >= trustedMinAp50;
  }

  /// Human-readable caveat for a detection the split cannot vouch for.
  static String reliabilityNote(String name) {
    final canonical = ProduceLabelAliases.canonicalize(name);
    final ap = measuredAp50[canonical];
    if (ap == null) {
      return '$canonical has no held-out examples; detection is unverified';
    }
    if (ap >= trustedMinAp50) return '';
    return '$canonical is unreliable (test AP50 ${ap.toStringAsFixed(2)})';
  }

  final double minConfidence;
  final int maxDetections;
  final double nmsIouThreshold;

  ScanTensorRunner? _runner;
  final FoodClassificationService _classifier;
  List<String> _labels;
  bool _isLoaded;
  ScanVisionFailure? _initializationFailure;

  /// Reason the last [initialize] call failed, or `null` if it succeeded.
  ScanVisionFailure? get initializationFailure => _initializationFailure;

  /// Detects every accepted item in [file], highest confidence first.
  ///
  /// [minConfidence] raises the floor above [defaultMinConfidence]. It can only
  /// tighten the gate: classes below [trustedMinAp50] keep their higher
  /// [lowReliabilityMinConfidence] floor regardless.
  Future<ScanVisionResult> detect(File file, {double? minConfidence}) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    if (!await initialize() || _runner == null) {
      return _failed(
        _initializationFailure ??
            const ScanVisionFailure(
              stage: ScanVisionStage.initialization,
              reason: 'Produce detector is not initialised',
            ),
      );
    }

    DetectorPreprocessResult prepared;
    try {
      prepared = await DetectorPreprocessor.fromFile(file);
    } on Object catch (error) {
      return _failed(
        ScanVisionFailure(
          stage: ScanVisionStage.decode,
          reason: 'Could not decode image for detection: $error',
          cause: error,
        ),
        imageWidth: null,
      );
    }

    final Float32List output;
    try {
      output = await _runInference(prepared.tensor);
    } on Object catch (error) {
      return _failed(
        ScanVisionFailure(
          stage: ScanVisionStage.execution,
          reason: 'Produce detector execution failed: $error',
          cause: error,
        ),
        prepared: prepared,
      );
    }
    stopwatch.stop();

    return _decode(
      output,
      prepared,
      inferenceDuration: stopwatch.elapsed,
      minConfidence: minConfidence,
    );
  }

  Future<Float32List> _runInference(Float32List tensor) async {
    final ScanTensorRunner? runner = _runner;
    if (runner == null) {
      throw StateError('Detector runner is not initialised');
    }
    final buffer = Float32List(outputChannels * anchorCount);
    runner.run(
      <Object?>[tensor],
      <Object?>[buffer],
    );
    return buffer;
  }

  /// Turns the raw head into pantry items.
  ///
  /// Separated from [detect] so the decode can be exercised directly in tests
  /// against recorded tensors, with no interpreter and no image file.
  Future<ScanVisionResult> _decode(
    List<double> output,
    DetectorPreprocessResult prepared, {
    Duration? inferenceDuration,
    double? minConfidence,
  }) async {
    final labels = _labels;
    final candidates = decodeDetections(
      output,
      labels: labels,
      prepared: prepared,
      minConfidence: minConfidence ?? this.minConfidence,
      nmsIouThreshold: nmsIouThreshold,
      maxDetections: maxDetections,
    );

    final items = <Map<String, dynamic>>[];
    for (final detection in candidates) {
      final classResult =
          await _classifier.classify(detection.name, isOnline: false);
      final canonicalName = classResult.canonicalName.isNotEmpty
          ? classResult.canonicalName
          : detection.name;

      items.add(<String, dynamic>{
        'name': canonicalName,
        'qty': 1.0,
        'unit': LocalVisionService.guessUnit(classResult.category),
        'category': classResult.category,
        'type': classResult.type,
        'confirmed': true,
        'confidence': detection.confidence,
        'source': 'offline_produce_detector',
        'modelSource': ScanModelSource.local.name,
        'box': <double>[
          detection.left,
          detection.top,
          detection.width,
          detection.height,
        ],
        'trusted': detection.isTrusted,
        'reliabilityNote': detection.reliabilityNote,
      });
    }

    final topItems = candidates.take(diagnosticTopK).toList();
    final diagnostics = ScanVisionDiagnostics(
      source: ScanModelSource.local,
      imageWidth: prepared.imageWidth,
      imageHeight: prepared.imageHeight,
      resizeWidth: prepared.scaledWidth,
      resizeHeight: prepared.scaledHeight,
      tensorShape: DetectorPreprocessor.tensorShape,
      tensorDtype: DetectorPreprocessor.tensorDtype,
      topIndices: topItems.map((ProduceDetection d) => d.classIndex).toList(),
      topLabels: topItems.map((ProduceDetection d) => d.name).toList(),
      topConfidences:
          topItems.map((ProduceDetection d) => d.confidence).toList(),
      inferenceDuration: inferenceDuration,
      rejectionReason: items.isEmpty
          ? _rejectionReason(prepared, output)
          : null,
    );

    if (items.isEmpty) {
      return ScanVisionResult.empty(
        source: ScanModelSource.local,
        diagnostics: diagnostics,
      );
    }

    return ScanVisionResult.success(
      source: ScanModelSource.local,
      items: items,
      diagnostics: diagnostics,
    );
  }

  /// Number of detections reported in diagnostics.
  static const int diagnosticTopK = 5;

  /// Explains an empty result concretely rather than emitting a generic string.
  String _rejectionReason(
    DetectorPreprocessResult prepared,
    List<double> output,
  ) {
    final labels = _labels;
    var bestScore = 0.0;
    var bestName = 'n/a';
    for (var a = 0; a < anchorCount; a++) {
      final index = bestClassIndexAt(output, a);
      final score = output[(boxChannelCount + index) * anchorCount + a];
      if (score > bestScore) {
        bestScore = score;
        bestName = labels[index];
      }
    }
    final floor = confidenceFloorFor(bestName);
    return 'no detection cleared the confidence floor '
        '(best $bestName ${bestScore.toStringAsFixed(3)} '
        'vs floor ${floor.toStringAsFixed(2)} '
        '${isTrusted(bestName) ? '' : 'untrusted class'}) for a '
        '${prepared.imageWidth}x${prepared.imageHeight} frame';
  }

  /// Loads the TFLite graph and label list from Flutter assets.
  ///
  /// Returns `true` when [detect] can run. Failures are recorded on
  /// [_initializationFailure] rather than thrown, so callers get a typed
  /// [ScanVisionStatus.failed] result instead of an exception.
  Future<bool> initialize() async {
    if (_isLoaded) return true;
    if (_initializationFailure != null) return false;

    if (kIsWeb) {
      _initializationFailure = const ScanVisionFailure(
        stage: ScanVisionStage.unsupportedPlatform,
        reason: 'On-device inference is not supported on web',
      );
      return false;
    }

    try {
      _runner ??= TfliteTensorRunner(
        await Interpreter.fromAsset(modelAssetPath),
      );

      if (_labels.isEmpty) {
        final String data = await rootBundle.loadString(labelsAssetPath);
        _labels = data
            .split('\n')
            .map((String line) => line.trim())
            .where((String line) => line.isNotEmpty)
            .toList();
      }

      if (_labels.length != classCount) {
        _initializationFailure = ScanVisionFailure(
          stage: ScanVisionStage.initialization,
          reason: 'Detector label asset has ${_labels.length} entries, '
              'expected $classCount',
        );
        _runner!.close();
        _runner = null;
        return false;
      }

      _isLoaded = true;
      return true;
    } on Object catch (error) {
      _initializationFailure = ScanVisionFailure(
        stage: ScanVisionStage.initialization,
        reason: 'Could not initialize produce detector: $error',
        cause: error,
      );
      _runner?.close();
      _runner = null;
      return false;
    }
  }

  ScanVisionResult _failed(
    ScanVisionFailure failure, {
    DetectorPreprocessResult? prepared,
    int? imageWidth,
    int? imageHeight,
  }) {
    return ScanVisionResult.failed(
      source: ScanModelSource.local,
      failure: failure,
      diagnostics: ScanVisionDiagnostics(
        source: ScanModelSource.local,
        imageWidth: imageWidth ?? prepared?.imageWidth,
        imageHeight: imageHeight ?? prepared?.imageHeight,
        tensorShape: DetectorPreprocessor.tensorShape,
        tensorDtype: DetectorPreprocessor.tensorDtype,
        failure: failure,
      ),
    );
  }

  void dispose() {
    _runner?.close();
    _runner = null;
    _isLoaded = false;
  }
}

/// One accepted detection, in original-image pixel coordinates.
class ProduceDetection {
  const ProduceDetection({
    required this.classIndex,
    required this.name,
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.isTrusted,
    required this.reliabilityNote,
  });

  /// Index into the detector's label list.
  final int classIndex;

  /// Canonical label, already passed through [ProduceLabelAliases].
  final String name;

  final double confidence;

  final double left;
  final double top;
  final double width;
  final double height;

  /// Whether the held-out split vouches for [name].
  final bool isTrusted;

  /// Non-empty when the class is below the trusted AP50 floor.
  final String reliabilityNote;

  double get right => left + width;

  double get bottom => top + height;

  double get area => width * height;

  /// Intersection over union against [other].
  double iou(ProduceDetection other) {
    final ix = math.max(0.0, math.min(right, other.right) - math.max(left, other.left));
    final iy =
        math.max(0.0, math.min(bottom, other.bottom) - math.max(top, other.top));
    final intersection = ix * iy;
    if (intersection <= 0) return 0;
    final union = area + other.area - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}

/// Decodes the raw detector head into deduplicated, reliability-gated detections.
///
/// Pure and synchronous so it can be unit-tested against recorded tensors.
///
/// The head is channel-major: element `(c, a)` lives at `c * anchorCount + a`.
List<ProduceDetection> decodeDetections(
  List<double> output, {
  required List<String> labels,
  required DetectorPreprocessResult prepared,
  double minConfidence = ProduceDetectorService.defaultMinConfidence,
  double nmsIouThreshold = ProduceDetectorService.defaultNmsIouThreshold,
  int maxDetections = ProduceDetectorService.defaultMaxDetections,
}) {
  const int anchors = ProduceDetectorService.anchorCount;
  const int boxChannels = ProduceDetectorService.boxChannelCount;
  final int size = ProduceDetectorService.inputSize;

  final raw = <ProduceDetection>[];

  for (var a = 0; a < anchors; a++) {
    final classIndex = bestClassIndexAt(output, a);
    final score = output[(boxChannels + classIndex) * anchors + a];

    final floor = ProduceDetectorService.confidenceFloorFor(labels[classIndex]);
    if (score < math.max(minConfidence, floor)) continue;

    // Normalized 0..1 center/size in letterbox space -> 640-space pixels.
    final cx = output[a] * size;
    final cy = output[anchors + a] * size;
    final w = output[2 * anchors + a] * size;
    final h = output[3 * anchors + a] * size;

    // Undo letterbox padding and scaling to land on original-image pixels.
    final scale = prepared.scale;
    final left = (cx - w / 2 - prepared.padX) / scale;
    final top = (cy - h / 2 - prepared.padY) / scale;
    final width = w / scale;
    final height = h / scale;

    if (width <= 0 || height <= 0) continue;
    if (left >= prepared.imageWidth || top >= prepared.imageHeight) continue;
    if (left + width <= 0 || top + height <= 0) continue;

    final name = ProduceLabelAliases.canonicalize(labels[classIndex]);
    raw.add(
      ProduceDetection(
        classIndex: classIndex,
        name: name,
        confidence: score,
        left: left,
        top: top,
        width: width,
        height: height,
        isTrusted: ProduceDetectorService.isTrusted(labels[classIndex]),
        reliabilityNote: ProduceDetectorService.reliabilityNote(labels[classIndex]),
      ),
    );
  }

  raw.sort((ProduceDetection a, ProduceDetection b) =>
      b.confidence.compareTo(a.confidence));

  final kept = <ProduceDetection>[];
  for (final detection in raw) {
    final suppressed = kept.any(
      (ProduceDetection existing) =>
          existing.classIndex == detection.classIndex &&
          existing.iou(detection) > nmsIouThreshold,
    );
    if (suppressed) continue;
    kept.add(detection);
    if (kept.length >= maxDetections) break;
  }

  return List<ProduceDetection>.unmodifiable(kept);
}

/// Index of the highest-scoring class channel for anchor [anchor].
///
/// Anchors are independent, so the caller can scan one anchor without touching
/// the rest of the tensor.
int bestClassIndexAt(List<double> output, int anchor) {
  const int anchors = ProduceDetectorService.anchorCount;
  const int boxChannels = ProduceDetectorService.boxChannelCount;
  var bestIndex = 0;
  var bestScore = double.negativeInfinity;
  for (var c = 0; c < ProduceDetectorService.classCount; c++) {
    final score = output[(boxChannels + c) * anchors + anchor];
    if (score > bestScore) {
      bestScore = score;
      bestIndex = c;
    }
  }
  return bestIndex;
}