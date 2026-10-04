import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/local_vision_service.dart';
import 'package:kooked/services/scan_vision_types.dart';

import '../helpers/fake_scan_vision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File image;

  setUp(() {
    image = writeTempPng(64, 48);
  });

  group('LocalVisionResult SUCCESS', () {
    test('returns predictions when top-1 clears the threshold', () async {
      final runner = FakeTensorRunner(<double>[0.05, 0.90, 0.03, 0.02]);
      final service = LocalVisionService(runner: runner, labels: testLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.status, ScanVisionStatus.success);
      expect(result.isSuccess, isTrue);
      expect(result.source, ScanModelSource.local);
      expect(result.items, isNotEmpty);
      expect((result.items.first['name'] as String).toLowerCase(), 'banana');
      expect(result.items.first['confidence'], closeTo(0.90, 1e-6));
      expect(result.userMessage, isNull);
      expect(runner.runCount, 1);

      service.dispose();
    });

    test('SUCCESS exposes full debug diagnostics', () async {
      final runner = FakeTensorRunner(<double>[0.05, 0.90, 0.03, 0.02]);
      final service = LocalVisionService(runner: runner, labels: testLabels);

      final result = await service.analyzeFoodImage(image);
      final d = result.diagnostics;

      expect(d.source, ScanModelSource.local);
      expect(d.imageWidth, 64);
      expect(d.imageHeight, 48);
      expect(d.cropWidth, 48);
      expect(d.cropHeight, 48);
      expect(d.cropX, 8);
      expect(d.cropY, 0);
      expect(d.resizeWidth, 224);
      expect(d.resizeHeight, 224);
      expect(d.interpolation, isNotNull);
      expect(d.tensorShape, <int>[1, 224, 224, 3]);
      expect(d.tensorDtype, 'float32');
      expect(d.normalizationMean, <double>[0.485, 0.456, 0.406]);
      expect(d.normalizationStd, <double>[0.229, 0.224, 0.225]);
      expect(d.topIndices, isNotEmpty);
      expect(d.topIndices.first, 1);
      expect(d.topLabels.first, 'banana');
      expect(d.topConfidences.first, closeTo(0.90, 1e-6));
      expect(d.inferenceDuration, isNotNull);
      expect(d.failure, isNull);

      expect(d.describe(), contains('tensorShape'));
      expect(d.toMap()['source'], 'local');

      service.dispose();
    });
  });

  group('LocalVisionResult EMPTY', () {
    test('returns EMPTY with a semantic message when confidence is too low', () async {
      final runner = FakeTensorRunner(spreadProbabilities);
      final service =
          LocalVisionService(runner: runner, labels: spreadLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.status, ScanVisionStatus.empty);
      expect(result.isEmpty, isTrue);
      expect(result.isFailed, isFalse);
      expect(result.items, isEmpty);
      expect(result.failure, isNull, reason: 'EMPTY is not a failure');
      expect(result.userMessage, ScanVisionMessages.noFoodDetected);
      expect(result.userMessage, 'No food items detected');

      service.dispose();
    });

    test('EMPTY still reports the scores that were rejected', () async {
      final runner = FakeTensorRunner(spreadProbabilities);
      final service =
          LocalVisionService(runner: runner, labels: spreadLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.diagnostics.topLabels, contains('banana'));
      expect(result.diagnostics.topConfidences.first, closeTo(0.24, 1e-6));

      service.dispose();
    });

    test('EMPTY never reports a server or network problem', () async {
      final runner = FakeTensorRunner(spreadProbabilities);
      final service =
          LocalVisionService(runner: runner, labels: spreadLabels);

      final message =
          (await service.analyzeFoodImage(image)).userMessage!.toLowerCase();

      for (final forbidden in <String>[
        'server',
        'unreachable',
        'connect',
        'network',
        'offline_food_ai',
      ]) {
        expect(message.contains(forbidden), isFalse,
            reason: 'EMPTY message must not mention "$forbidden"');
      }

      service.dispose();
    });
  });

  group('LocalVisionResult FAILED', () {
    test('reports FAILED with the real reason when execution throws', () async {
      final runner = FakeTensorRunner(<double>[0.9, 0.05, 0.03, 0.02])
        ..errorOnRun = StateError('tensor shape mismatch');

      final service = LocalVisionService(runner: runner, labels: testLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.status, ScanVisionStatus.failed);
      expect(result.isFailed, isTrue);
      expect(result.items, isEmpty);
      expect(result.failure, isNotNull);
      expect(result.failure!.stage, ScanVisionStage.execution);
      expect(result.failure!.reason, contains('Model execution failed'));
      expect(result.failure!.reason, contains('tensor shape mismatch'));
      expect(result.diagnostics.failure, isNotNull);

      service.dispose();
    });

    test('reports FAILED with the real reason when the image cannot be read', () async {
      final runner = FakeTensorRunner(<double>[0.9, 0.05, 0.03, 0.02]);
      final service = LocalVisionService(runner: runner, labels: testLabels);

      final result = await service.analyzeFoodImage(
        File('definitely_missing_image.jpg'),
      );

      expect(result.status, ScanVisionStatus.failed);
      expect(result.failure!.stage, ScanVisionStage.decode);
      expect(result.failure!.reason, contains('Could not read or decode image'));
      expect(result.userMessage, isNot(contains('AI server')));

      service.dispose();
    });

    test('reports FAILED when the model cannot be initialized', () async {
      final service = LocalVisionService();

      final result = await service.analyzeFoodImage(image);

      // Host-dependent: with the native library present this reaches decode,
      // without it the failure is reported at initialization. Both are FAILED
      // with a real reason rather than an empty list.
      expect(result.isFailed, isTrue,
          reason: 'a missing native library must not masquerade as EMPTY');
      expect(result.isEmpty, isFalse);
      expect(result.failure!.reason, isNotEmpty);
      expect(
        result.failure!.stage,
        anyOf(ScanVisionStage.initialization, ScanVisionStage.decode),
      );

      service.dispose();
    });
  });

  group('LocalVisionService calibrated confidence gate', () {
    test('default threshold is the calibrated 0.85', () {
      expect(LocalVisionService().defaultConfidenceThreshold, 0.85);
      expect(
        LocalVisionService.calibratedMinConfidence,
        LocalVisionService().defaultConfidenceThreshold,
      );
    });

    test('a confident correct prediction succeeds', () async {
      final runner = FakeTensorRunner(
        produceDistribution(<int, double>{0: 0.97}),
      );
      final service = LocalVisionService(runner: runner, labels: produceLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.isSuccess, isTrue);
      expect(result.items.first['name'], 'Apple');
      expect(result.items.first['confidence'], closeTo(0.97, 1e-6));
      expect(result.diagnostics.rejectionReason, isNull);
      service.dispose();
    });

    test('an undecided capsicum frame is rejected, not guessed', () async {
      // bell pepper 0.47 / capsicum 0.46: the model cannot separate the two, so
      // top-1 sits far below the floor and the frame must be rejected outright
      // rather than resolved to an arbitrary member of the family.
      final runner = FakeTensorRunner(
        produceDistribution(<int, double>{3: 0.47, 5: 0.46}),
      );
      final service = LocalVisionService(runner: runner, labels: produceLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.isEmpty, isTrue);
      expect(result.isFailed, isFalse);
      expect(result.items, isEmpty);
      expect(result.diagnostics.rejectionReason, contains('below floor'));
      service.dispose();
    });

    test('a confident capsicum prediction collapses to one Capsicum item', () async {
      // bell pepper wins outright; capsicum is the runner-up inside the family.
      // Both canonicalise to Capsicum, so the dedupe must yield exactly one item.
      final runner = FakeTensorRunner(
        produceDistribution(<int, double>{3: 0.90, 5: 0.05}),
      );
      final service = LocalVisionService(runner: runner, labels: produceLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.isSuccess, isTrue);
      expect(
        result.items.where((e) => e['name'] == 'Capsicum').length,
        1,
        reason: 'a collapsed family must never add duplicate items',
      );
      service.dispose();
    });

    test('corn and sweetcorn never both appear', () async {
      final runner = FakeTensorRunner(
        produceDistribution(<int, double>{9: 0.88, 31: 0.06}),
      );
      final service = LocalVisionService(runner: runner, labels: produceLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.isSuccess, isTrue);
      final names = result.items.map((e) => e['name']).toSet();
      expect(names.where((n) => n == 'Corn').length, 1);
      service.dispose();
    });

    test('records a rejection reason naming the threshold', () async {
      final runner = FakeTensorRunner(
        produceDistribution(<int, double>{0: 0.50}),
      );
      final service = LocalVisionService(runner: runner, labels: produceLabels);

      final result = await service.analyzeFoodImage(image);

      expect(result.isEmpty, isTrue);
      expect(result.diagnostics.rejectionReason, contains('0.5000'));
      expect(result.diagnostics.rejectionReason, contains('0.8500'));
      expect(result.diagnostics.toMap()['rejectionReason'], isNotNull);
      expect(result.diagnostics.describe(), contains('rejected'));
      service.dispose();
    });

    test('threshold stays overridable for calibration experiments', () async {
      final runner = FakeTensorRunner(
        produceDistribution(<int, double>{0: 0.50}),
      );
      final service = LocalVisionService(
        runner: runner,
        labels: produceLabels,
        confidenceThreshold: 0.40,
      );

      final result = await service.analyzeFoodImage(image);

      expect(result.isSuccess, isTrue);
      service.dispose();
    });

    test('minConfidence overrides the default per call', () async {
      final runner = FakeTensorRunner(
        produceDistribution(<int, double>{0: 0.50}),
      );
      final service = LocalVisionService(runner: runner, labels: produceLabels);

      final strict = await service.analyzeFoodImage(image);
      final lenient =
          await service.analyzeFoodImage(image, minConfidence: 0.40);

      expect(strict.isEmpty, isTrue);
      expect(lenient.isSuccess, isTrue);
      service.dispose();
    });
  });
}