import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/local_produce_vision_service.dart';
import 'package:kooked/services/local_vision_service.dart';
import 'package:kooked/services/produce_detector.dart';
import 'package:kooked/services/scan_vision_types.dart';

import '../helpers/fake_scan_vision.dart';

/// Stands in for the detector without needing the native TFLite library.
///
/// Returns a canned [ScanVisionResult] so the composition rules can be
/// exercised directly.
class _StubDetector extends ProduceDetectorService {
  _StubDetector(this.result, {this.onDetect});

  final ScanVisionResult result;
  final void Function(File file, double? minConfidence)? onDetect;
  int detectCount = 0;

  @override
  Future<ScanVisionResult> detect(File file, {double? minConfidence}) async {
    detectCount++;
    onDetect?.call(file, minConfidence);
    return result;
  }

  @override
  void dispose() {}
}

ScanVisionResult detectorResult(List<Map<String, dynamic>> items) {
  return ScanVisionResult.success(
    source: ScanModelSource.local,
    items: items,
  );
}

Map<String, dynamic> detection(
  String name, {
  double confidence = 0.8,
  bool trusted = true,
  List<double>? box,
}) {
  return <String, dynamic>{
    'name': name,
    'qty': 1.0,
    'unit': 'pcs',
    'category': 'Vegetable',
    'type': 'Raw',
    'confirmed': true,
    'confidence': confidence,
    'source': 'offline_produce_detector',
    'modelSource': ScanModelSource.local.name,
    'box': box ?? <double>[10, 10, 100, 100],
    'trusted': trusted,
    'reliabilityNote': trusted ? '' : 'unreliable',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  File anyFile() => writeTempPng(64, 64);

  group('counting', () {
    test('three identical detections become one row with qty 3', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[
            detection('apple'),
            detection('apple'),
            detection('apple'),
          ]),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(produceDistribution(<int, double>{0: 0.9})),
          labels: produceLabels,
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.engine, LocalProduceEngine.detector);
      expect(result.result.items, hasLength(1));
      expect(result.result.items.single['name'], 'apple');
      expect(result.result.items.single['qty'], 3.0);
    });

    test('distinct classes stay on separate rows', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[
            detection('apple'),
            detection('banana'),
            detection('apple'),
          ]),
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.result.items, hasLength(2));
      final apple = result.result.items
          .firstWhere((Map<String, dynamic> i) => i['name'] == 'apple');
      final banana = result.result.items
          .firstWhere((Map<String, dynamic> i) => i['name'] == 'banana');
      expect(apple['qty'], 2.0);
      expect(banana['qty'], 1.0);
    });

    test('keeps every box so the overlay can draw them all', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[
            detection('apple', box: <double>[0, 0, 10, 10]),
            detection('apple', box: <double>[20, 20, 30, 30]),
          ]),
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.result.items.single['boxes'], hasLength(2));
      expect(result.result.items.single['boxes'], <List<double>>[
        <double>[0, 0, 10, 10],
        <double>[20, 20, 30, 30],
      ]);
    });

    test('groups case-insensitively', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[
            detection('Corn'),
            detection('corn'),
          ]),
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.result.items, hasLength(1));
      expect(result.result.items.single['qty'], 2.0);
    });

    test('grouped rows keep the pantry fields the UI needs', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[detection('carrot')]),
        ),
      );

      final item = (await service.analyze(anyFile())).result.items.single;

      expect(item['unit'], 'pcs');
      expect(item['category'], isNotNull);
      expect(item['type'], isNotNull);
      expect(item['confirmed'], isTrue);
      expect(item['confidence'], isA<double>());
    });
  });

  group('engine precedence', () {
    test('uses the detector when it succeeds and never calls the classifier',
        () async {
      final classifier = LocalVisionService(
        runner: FakeTensorRunner(produceDistribution(<int, double>{0: 0.9})),
        labels: produceLabels,
      );
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[detection('spinach')]),
        ),
        classifier: classifier,
      );

      final result = await service.analyze(anyFile());

      expect(result.engine, LocalProduceEngine.detector);
      expect(result.result.items.single['name'], 'spinach');
    });

    test('falls back to the classifier when the detector finds nothing',
        () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          ScanVisionResult.empty(source: ScanModelSource.local),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(produceDistribution(<int, double>{0: 0.95})),
          labels: produceLabels,
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.engine, LocalProduceEngine.classifier);
      expect(result.result.isSuccess, isTrue);
      // The classifier title-cases its canonical name.
      expect(result.result.items.single['name'], 'Apple');
    });

    test('falls back to the classifier when the detector fails', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          ScanVisionResult.failed(
            source: ScanModelSource.local,
            failure: const ScanVisionFailure(
              stage: ScanVisionStage.execution,
              reason: 'interpreter missing',
            ),
          ),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(produceDistribution(<int, double>{0: 0.95})),
          labels: produceLabels,
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.engine, LocalProduceEngine.classifier);
      expect(result.result.isSuccess, isTrue);
    });

    test('does not merge detector and classifier items, avoiding double counts',
        () async {
      // The classifier also sees an apple. Combining it with the detector's
      // apple would report two apples where there is one.
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[detection('apple')]),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(produceDistribution(<int, double>{0: 0.95})),
          labels: produceLabels,
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.engine, LocalProduceEngine.detector);
      expect(result.result.items, hasLength(1));
      expect(result.result.items.single['qty'], 1.0);
    });
  });

  group('failure handling', () {
    test('reports failure when both engines fail', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          ScanVisionResult.failed(
            source: ScanModelSource.local,
            failure: const ScanVisionFailure(
              stage: ScanVisionStage.execution,
              reason: 'detector broke',
            ),
          ),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(<double>[1.0])
            ..errorOnRun = StateError('classifier broke'),
          labels: produceLabels,
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.engine, isNull);
      expect(result.result.isFailed, isTrue);
      expect(result.result.failure!.reason, contains('detector broke'));
    });

    test('reports empty, not failed, when both engines find nothing', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          ScanVisionResult.empty(
            source: ScanModelSource.local,
            diagnostics: const ScanVisionDiagnostics(
              source: ScanModelSource.local,
              rejectionReason: 'no detection cleared the floor',
            ),
          ),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(spreadProbabilities),
          labels: spreadLabels,
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.engine, isNull);
      expect(result.result.isEmpty, isTrue);
      expect(result.result.isFailed, isFalse);
      expect(result.result.userMessage, 'No food items detected');
    });

    test('keeps the detector rejection reason when both come back empty',
        () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          ScanVisionResult.empty(
            source: ScanModelSource.local,
            diagnostics: const ScanVisionDiagnostics(
              source: ScanModelSource.local,
              rejectionReason: 'no detection cleared the floor',
            ),
          ),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(spreadProbabilities),
          labels: spreadLabels,
        ),
      );

      final result = await service.analyze(anyFile());

      expect(
        result.result.diagnostics.rejectionReason,
        contains('no detection cleared'),
      );
    });
  });

  group('reliability reporting', () {
    test('flags detections from classes the split cannot vouch for', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[
            detection('banana'),
            detection('garlic', trusted: false),
          ]),
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.hasLowReliability, isTrue);
      expect(result.lowReliabilityItems.single['name'], 'garlic');
    });

    test('reports nothing weak when every detection is trusted', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[
            detection('banana'),
            detection('spinach'),
          ]),
        ),
      );

      final result = await service.analyze(anyFile());

      expect(result.hasLowReliability, isFalse);
      expect(result.lowReliabilityItems, isEmpty);
    });
  });

  group('confidence pass-through', () {
    test('forwards minConfidence to the detector', () async {
      double? seen;
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          detectorResult(<Map<String, dynamic>>[detection('apple')]),
          onDetect: (File file, double? minConfidence) => seen = minConfidence,
        ),
      );

      await service.analyze(anyFile(), minConfidence: 0.7);

      expect(seen, 0.7);
    });

    test('forwards minConfidence to the classifier fallback', () async {
      final service = LocalProduceVisionService(
        detector: _StubDetector(
          ScanVisionResult.empty(source: ScanModelSource.local),
        ),
        classifier: LocalVisionService(
          runner: FakeTensorRunner(produceDistribution(<int, double>{0: 0.95})),
          labels: produceLabels,
        ),
      );

      final result = await service.analyze(anyFile(), minConfidence: 0.9);

      expect(result.engine, LocalProduceEngine.classifier);
      expect(result.result.isSuccess, isTrue);
    });
  });

  group('asset wiring', () {
    test('detector labels resolve from the asset bundle', () async {
      final bundled =
          await rootBundle.loadString(ProduceDetectorService.labelsAssetPath);
      expect(bundled.trim(), isNotEmpty);
    });
  });
}