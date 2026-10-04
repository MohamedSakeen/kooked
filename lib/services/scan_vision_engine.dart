import 'dart:io';

import 'scan_vision_types.dart';

/// Ordering and participation of the two inference engines.
///
/// The engine is decoupled from any transport: `scan_screen.dart` chooses a
/// strategy, and the engine resolves it without any HTTP catch block
/// controlling whether local inference runs.
enum ScanVisionStrategy {
  /// Try on-device first, then cloud.
  localFirst,

  /// Try cloud first, then on-device.
  cloudFirst,

  /// On-device only; never contact the cloud.
  localOnly,

  /// Cloud only; never load the on-device model.
  cloudOnly;

  bool get allowsLocal => this != ScanVisionStrategy.cloudOnly;

  bool get allowsCloud => this != ScanVisionStrategy.localOnly;

  /// Engine attempted before any fallback.
  ScanModelSource get primary => switch (this) {
        ScanVisionStrategy.localFirst => ScanModelSource.local,
        ScanVisionStrategy.localOnly => ScanModelSource.local,
        ScanVisionStrategy.cloudFirst => ScanModelSource.cloud,
        ScanVisionStrategy.cloudOnly => ScanModelSource.cloud,
      };

  ScanModelSource get secondary => switch (this) {
        ScanVisionStrategy.localFirst => ScanModelSource.cloud,
        ScanVisionStrategy.localOnly => ScanModelSource.cloud,
        ScanVisionStrategy.cloudFirst => ScanModelSource.local,
        ScanVisionStrategy.cloudOnly => ScanModelSource.local,
      };

  String get analyzingMessage => switch (this) {
        ScanVisionStrategy.localFirst =>
          'On-device Produce AI is analyzing your food items...',
        ScanVisionStrategy.localOnly =>
          'On-device Produce AI is analyzing your food items...',
        ScanVisionStrategy.cloudFirst =>
          'Gemini AI is analyzing ingredients & portions...',
        ScanVisionStrategy.cloudOnly =>
          'Gemini AI is analyzing ingredients & portions...',
      };
}

typedef ScanLocalRunner = Future<ScanVisionResult> Function(
  File file, {
  double? minConfidence,
});

typedef ScanCloudRunner = Future<List<Map<String, dynamic>>> Function(File file);

/// Resolves a [ScanVisionStrategy] into a single [ScanVisionResult].
///
/// Precedence rules, applied to the primary and fallback outcomes:
///
/// 1. Either engine returning predictions wins immediately.
/// 2. If any engine reports [ScanVisionStatus.empty], the result is EMPTY.
///    An empty verdict is a valid answer and is never converted into a network
///    or server error.
/// 3. Only when both engines report [ScanVisionStatus.failed] is the result
///    FAILED, and it carries the primary engine's real reason plus the
///    fallback's reason.
class ScanVisionEngine {
  const ScanVisionEngine({
    required this.runLocal,
    required this.runCloud,
  });

  final ScanLocalRunner runLocal;
  final ScanCloudRunner runCloud;

  Future<ScanVisionResult> analyze(
    File file, {
    ScanVisionStrategy strategy = ScanVisionStrategy.cloudFirst,
    double? minConfidence,
  }) async {
    switch (strategy) {
      case ScanVisionStrategy.localOnly:
        return _runLocalSafely(file, minConfidence);
      case ScanVisionStrategy.cloudOnly:
        return _runCloudSafely(file);
      case ScanVisionStrategy.localFirst:
      case ScanVisionStrategy.cloudFirst:
        return _resolveWithFallback(file, strategy, minConfidence);
    }
  }

  Future<ScanVisionResult> _resolveWithFallback(
    File file,
    ScanVisionStrategy strategy,
    double? minConfidence,
  ) async {
    final ScanVisionResult primary;
    final ScanVisionResult secondary;

    if (strategy.primary == ScanModelSource.local) {
      primary = await _runLocalSafely(file, minConfidence);
      if (primary.isSuccess) return primary;
      secondary = await _runCloudSafely(file);
    } else {
      primary = await _runCloudSafely(file);
      if (primary.isSuccess) return primary;
      secondary = await _runLocalSafely(file, minConfidence);
    }

    if (secondary.isSuccess) return secondary;

    if (primary.isEmpty) {
      return ScanVisionResult.empty(
        source: primary.source,
        diagnostics: primary.diagnostics,
        fallbackFailure: secondary.failure,
      );
    }

    if (secondary.isEmpty) {
      return ScanVisionResult.empty(
        source: secondary.source,
        diagnostics: secondary.diagnostics,
        fallbackFailure: primary.failure,
      );
    }

    return ScanVisionResult.failed(
      source: primary.source,
      failure: primary.failure!,
      diagnostics: primary.diagnostics,
      fallbackFailure: secondary.failure,
    );
  }

  Future<ScanVisionResult> _runLocalSafely(
    File file,
    double? minConfidence,
  ) async {
    try {
      return await runLocal(file, minConfidence: minConfidence);
    } on Object catch (error) {
      return ScanVisionResult.failed(
        source: ScanModelSource.local,
        failure: ScanVisionFailure(
          stage: ScanVisionStage.execution,
          reason: 'On-device inference threw: $error',
          cause: error,
        ),
      );
    }
  }

  Future<ScanVisionResult> _runCloudSafely(File file) async {
    try {
      final items = await runCloud(file);
      if (items.isEmpty) {
        return ScanVisionResult.empty(
          source: ScanModelSource.cloud,
          diagnostics: const ScanVisionDiagnostics(
            source: ScanModelSource.cloud,
          ),
        );
      }
      return ScanVisionResult.success(
        source: ScanModelSource.cloud,
        items: items,
      );
    } on ScanVisionException catch (error) {
      return ScanVisionResult.failed(
        source: ScanModelSource.cloud,
        failure: ScanVisionFailure(
          stage: ScanVisionStage.execution,
          reason: error.message,
          cause: error,
        ),
      );
    } on Object catch (error) {
      return ScanVisionResult.failed(
        source: ScanModelSource.cloud,
        failure: ScanVisionFailure(
          stage: ScanVisionStage.execution,
          reason: 'Cloud inference failed: ${_cleanError(error)}',
          cause: error,
        ),
      );
    }
  }

  static String _cleanError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text;
  }
}