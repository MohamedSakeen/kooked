import 'dart:io';

import 'package:kooked/services/local_vision_service.dart';
import 'package:kooked/services/produce_detector.dart';
import 'package:kooked/services/scan_vision_types.dart';

/// Which on-device model produced a result.
enum LocalProduceEngine {
  /// Multi-item detector; the only local model that can count.
  detector('Produce Detector'),

  /// Whole-frame classifier; falls back when the detector finds nothing.
  classifier('Food Classifier');

  const LocalProduceEngine(this.displayName);

  final String displayName;
}

/// Result of on-device analysis, including which local model answered.
class LocalProduceResult {
  const LocalProduceResult(this.result, this.engine);

  final ScanVisionResult result;

  /// `null` when the local path produced no answer at all.
  final LocalProduceEngine? engine;

  /// Items whose class the held-out split cannot vouch for.
  List<Map<String, dynamic>> get lowReliabilityItems => result.items
      .where((Map<String, dynamic> item) => item['trusted'] == false)
      .toList();

  bool get hasLowReliability => lowReliabilityItems.isNotEmpty;
}

/// On-device analysis that prefers the detector and falls back to the
/// classifier.
///
/// The two models fail in different ways, which is what makes this
/// composition useful rather than redundant:
///
/// * The detector can count and localize, but its measured recall is ~0.36 and
///   19 of 31 classes sit below a usable AP50. It misses items.
/// * The classifier is far more sensitive on a single dominant item, but can
///   only ever name one thing, so it cannot count.
///
/// The detector therefore runs first, because counting is the capability the
/// app needs and only it provides. The classifier runs only when the detector
/// returns nothing, which covers the frames where a large centred item is
/// recognized confidently but missed as a detection.
///
/// Results from the two models are deliberately **never merged**. Combining a
/// detector that counts two bananas with a classifier that also sees a banana
/// would double-count, and there is no evidence available at runtime to decide
/// which model is right.
class LocalProduceVisionService {
  LocalProduceVisionService({
    ProduceDetectorService? detector,
    LocalVisionService? classifier,
  })  : _detector = detector ?? ProduceDetectorService(),
        _classifier = classifier ?? LocalVisionService();

  final ProduceDetectorService _detector;
  final LocalVisionService _classifier;

  /// Analyzes [file] on-device, returning the result plus the engine that
  /// produced it.
  Future<LocalProduceResult> analyze(
    File file, {
    double? minConfidence,
  }) async {
    final ScanVisionResult detected = await _detector.detect(
      file,
      minConfidence: minConfidence,
    );

    if (detected.isSuccess) {
      return LocalProduceResult(
        _withCountedQuantities(detected),
        LocalProduceEngine.detector,
      );
    }

    // The detector either found nothing acceptable or could not run. A
    // classifier verdict is still informative in both cases.
    final ScanVisionResult classified = await _classifier.analyzeFoodImage(
      file,
      minConfidence: minConfidence,
    );

    if (classified.isSuccess) {
      return LocalProduceResult(classified, LocalProduceEngine.classifier);
    }

    // Neither engine answered. Report the detector's reason as primary since
    // it was tried first, and keep the classifier's as the fallback reason.
    if (detected.isFailed && classified.isFailed) {
      return LocalProduceResult(
        ScanVisionResult.failed(
          source: ScanModelSource.local,
          failure: detected.failure!,
          diagnostics: detected.diagnostics,
          fallbackFailure: classified.failure,
        ),
        null,
      );
    }

    if (detected.isEmpty && classified.isEmpty) {
      return LocalProduceResult(
        ScanVisionResult.empty(
          source: ScanModelSource.local,
          // Keep the detector's reason: it is the model that actually ran
          // first and its thresholds are the ones that rejected the frame.
          diagnostics: detected.diagnostics,
          fallbackFailure: classified.failure,
        ),
        null,
      );
    }

    // One engine failed while the other merely found nothing.
    return LocalProduceResult(
      ScanVisionResult.failed(
        source: ScanModelSource.local,
        failure: (detected.isFailed ? detected : classified).failure!,
        diagnostics: detected.diagnostics,
        fallbackFailure:
            (detected.isFailed ? classified : detected).failure,
      ),
      null,
    );
  }

  /// Collapses same-class detections into counted rows.
  ///
  /// The detector emits one box per item, so three apples arrive as three rows.
  /// The pantry is quantity-based, so identical detections are merged into one
  /// row whose `qty` is the number of distinct boxes. Merging keeps the
  /// existing quantity editing and duplicate-merge behaviour working
  /// unchanged.
  static ScanVisionResult _withCountedQuantities(ScanVisionResult result) {
    final List<Map<String, dynamic>> grouped = <Map<String, dynamic>>[];
    final Map<String, Map<String, dynamic>> byName =
        <String, Map<String, dynamic>>{};

    for (final item in result.items) {
      final key = (item['name'] as String).toLowerCase();
      final existing = byName[key];
      if (existing == null) {
        final copy = Map<String, dynamic>.of(item);
        copy['qty'] = 1.0;
        copy['boxes'] = <List<double>>[
          (item['box'] as List<double>),
        ];
        byName[key] = copy;
        grouped.add(copy);
        continue;
      }

      existing['qty'] = (existing['qty'] as double) + 1.0;
      (existing['boxes'] as List<List<double>>).add(item['box'] as List<double>);
    }

    return ScanVisionResult(
      status: result.status,
      source: result.source,
      items: List<Map<String, dynamic>>.unmodifiable(grouped),
      diagnostics: result.diagnostics,
      failure: result.failure,
      fallbackFailure: result.fallbackFailure,
    );
  }

  void dispose() {
    _detector.dispose();
    _classifier.dispose();
  }
}