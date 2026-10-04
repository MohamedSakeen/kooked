import 'package:image/image.dart' as img;

/// Engine that produced (or was attempted for) a scan result.
///
/// Replaces the previous string-valued `_activeModelSource` flag so engine
/// selection and branching are compile-time checked instead of substring
/// matching.
enum ScanModelSource {
  local('On-Device Produce Model'),
  cloud('Gemini 1.5 Flash Vision AI');

  const ScanModelSource(this.displayName);

  final String displayName;

  bool get isLocal => this == ScanModelSource.local;

  bool get isCloud => this == ScanModelSource.cloud;
}

/// Terminal outcome of a single inference attempt.
///
/// The three states are deliberately distinct: a model that ran correctly but
/// produced nothing usable ([empty]) is NOT an error and must never be
/// reported as one.
enum ScanVisionStatus {
  /// One or more predictions cleared the decision logic.
  success,

  /// Model initialized, executed, and returned scores, but confidence /
  /// decision logic rejected every candidate.
  empty,

  /// Model could not initialize, decode input, allocate, or execute.
  failed,
}

/// Pipeline stage at which a [ScanVisionStatus.failed] result originated.
enum ScanVisionStage {
  unsupportedPlatform,
  initialization,
  decode,
  execution,
}

/// Concrete, surfaced cause of a failure.
///
/// Failures are recorded and exposed rather than swallowed into an empty list.
class ScanVisionFailure {
  const ScanVisionFailure({
    required this.stage,
    required this.reason,
    this.cause,
  });

  final ScanVisionStage stage;

  /// Human-readable, already-specific failure text.
  final String reason;

  /// Original error or stack trace, when available.
  final Object? cause;

  @override
  String toString() => '${stage.name}: $reason';
}

/// Semantic, user-facing copy for non-success outcomes.
class ScanVisionMessages {
  const ScanVisionMessages._();

  /// Shown when the model ran successfully but detected nothing acceptable.
  static const String noFoodDetected = 'No food items detected';
}

/// Structured diagnostics for one inference attempt.
///
/// Populated for every outcome and intended for debug builds and tests. The UI
/// renders only [ScanVisionResult.userMessage] plus the engine banner, so this
/// payload is never exposed in release presentation.
class ScanVisionDiagnostics {
  const ScanVisionDiagnostics({
    required this.source,
    this.imageWidth,
    this.imageHeight,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.resizeWidth,
    this.resizeHeight,
    this.interpolation,
    this.tensorShape,
    this.tensorDtype,
    this.normalizationMean,
    this.normalizationStd,
    this.topIndices = const [],
    this.topLabels = const [],
    this.topConfidences = const [],
    this.inferenceDuration,
    this.failure,
    this.rejectionReason,
  });

  final ScanModelSource source;

  final int? imageWidth;
  final int? imageHeight;

  final int? cropX;
  final int? cropY;
  final int? cropWidth;
  final int? cropHeight;

  final int? resizeWidth;
  final int? resizeHeight;

  final img.Interpolation? interpolation;

  /// Expected model input shape, e.g. `[1, 224, 224, 3]`.
  final List<int>? tensorShape;

  /// Model-facing element type.
  final String? tensorDtype;

  final List<double>? normalizationMean;
  final List<double>? normalizationStd;

  /// Class indices ordered by descending confidence.
  final List<int> topIndices;

  /// Labels aligned with [topIndices].
  final List<String> topLabels;

  /// Probabilities aligned with [topIndices].
  final List<double> topConfidences;

  final Duration? inferenceDuration;

  final ScanVisionFailure? failure;

  /// Why an otherwise successful inference produced no items.
  ///
  /// Set only on [ScanVisionStatus.empty]. Distinguishes "the frame looked
  /// nothing like any known class" from "the model could not choose between two
  /// classes", which call for different remedies and must not be silently
  /// collapsed into the same generic message.
  final String? rejectionReason;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'source': source.name,
      'image': imageWidth == null
          ? null
          : '${imageWidth}x$imageHeight',
      'crop': cropWidth == null
          ? null
          : '${cropWidth}x$cropHeight @ ($cropX,$cropY)',
      'resize': resizeWidth == null
          ? null
          : '${resizeWidth}x$resizeHeight',
      'interpolation': interpolation?.name,
      'tensorShape': tensorShape,
      'tensorDtype': tensorDtype,
      'normalizationMean': normalizationMean,
      'normalizationStd': normalizationStd,
      'topIndices': topIndices,
      'topLabels': topLabels,
      'topConfidences': topConfidences,
      'inferenceMs': inferenceDuration?.inMilliseconds,
      'rejectionReason': rejectionReason,
      'failure': failure?.toString(),
    };
  }

  String describe() {
    final buffer = StringBuffer()
      ..writeln('source        : ${source.name}')
      ..writeln('image         : ${imageWidth}x$imageHeight')
      ..writeln(
          'crop          : ${cropWidth}x$cropHeight @ ($cropX,$cropY)')
      ..writeln('resize        : ${resizeWidth}x$resizeHeight')
      ..writeln('interpolation : ${interpolation?.name}')
      ..writeln('tensorShape   : $tensorShape')
      ..writeln('tensorDtype   : $tensorDtype')
      ..writeln('mean          : $normalizationMean')
      ..writeln('std           : $normalizationStd');

    if (topLabels.isNotEmpty) {
      buffer.writeln('topK          :');
      for (var i = 0; i < topLabels.length; i++) {
        final confidence =
            i < topConfidences.length ? topConfidences[i] : double.nan;
        final index = i < topIndices.length ? topIndices[i] : -1;
        buffer.writeln('  #$index ${topLabels[i]} -> ${confidence.toStringAsFixed(4)}');
      }
    }

    buffer
      ..writeln('inferenceMs   : ${inferenceDuration?.inMilliseconds}')
      ..writeln('rejected      : ${rejectionReason ?? 'none'}')
      ..write('failure       : ${failure?.toString() ?? 'none'}');
    return buffer.toString();
  }
}

/// Immutable outcome of a scan attempt.
class ScanVisionResult {
  const ScanVisionResult({
    required this.status,
    required this.source,
    required this.items,
    required this.diagnostics,
    this.failure,
    this.fallbackFailure,
  });

  factory ScanVisionResult.success({
    required ScanModelSource source,
    required List<Map<String, dynamic>> items,
    ScanVisionDiagnostics? diagnostics,
  }) {
    return ScanVisionResult(
      status: ScanVisionStatus.success,
      source: source,
      items: List<Map<String, dynamic>>.unmodifiable(items),
      diagnostics: diagnostics ?? ScanVisionDiagnostics(source: source),
    );
  }

  factory ScanVisionResult.empty({
    required ScanModelSource source,
    ScanVisionDiagnostics? diagnostics,
    ScanVisionFailure? fallbackFailure,
  }) {
    return ScanVisionResult(
      status: ScanVisionStatus.empty,
      source: source,
      items: const <Map<String, dynamic>>[],
      diagnostics: diagnostics ?? ScanVisionDiagnostics(source: source),
      fallbackFailure: fallbackFailure,
    );
  }

  factory ScanVisionResult.failed({
    required ScanModelSource source,
    required ScanVisionFailure failure,
    ScanVisionDiagnostics? diagnostics,
    ScanVisionFailure? fallbackFailure,
  }) {
    return ScanVisionResult(
      status: ScanVisionStatus.failed,
      source: source,
      items: const <Map<String, dynamic>>[],
      diagnostics: diagnostics ?? ScanVisionDiagnostics(source: source),
      failure: failure,
      fallbackFailure: fallbackFailure,
    );
  }

  final ScanVisionStatus status;
  final ScanModelSource source;

  /// Predictions; always empty unless [status] is [ScanVisionStatus.success].
  final List<Map<String, dynamic>> items;

  final ScanVisionDiagnostics diagnostics;

  /// Why this attempt failed. Non-null exactly when [isFailed].
  final ScanVisionFailure? failure;

  /// Failure recorded from the engine that was tried but is not being reported.
  final ScanVisionFailure? fallbackFailure;

  bool get isSuccess => status == ScanVisionStatus.success;

  bool get isEmpty => status == ScanVisionStatus.empty;

  bool get isFailed => status == ScanVisionStatus.failed;

  /// Message to surface to the user.
  ///
  /// Returns `null` on success. On [ScanVisionStatus.empty] this is a neutral
  /// semantic statement and must never be phrased as a network or server
  /// error.
  String? get userMessage {
    if (isSuccess) return null;
    if (isEmpty) return ScanVisionMessages.noFoodDetected;
    return failure?.reason ?? 'Scan failed';
  }
}

/// Error carrying an already-human-readable reason through the engine.
class ScanVisionException implements Exception {
  const ScanVisionException(this.message);

  final String message;

  @override
  String toString() => message;
}