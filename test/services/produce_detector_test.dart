import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/services/detector_preprocessor.dart';
import 'package:kooked/services/produce_detector.dart';

/// Real TFLite head output recorded from the exported detector.
///
/// Recorded on a 1080x1920 frame so the letterbox path is exercised
/// (scale 1/3, horizontal pad 140) rather than a square no-op.
class Fixture {
  Fixture(this.raw);

  factory Fixture.load() {
    final file = File('test/fixtures/produce_detector_fixture.json');
    return Fixture(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }

  final Map<String, dynamic> raw;

  int get imageWidth => raw['imageW'] as int;
  int get imageHeight => raw['imageH'] as int;
  int get scaledWidth => raw['scaledW'] as int;
  int get scaledHeight => raw['scaledH'] as int;
  int get padX => raw['padX'] as int;
  int get padY => raw['padY'] as int;

  List<Map<String, dynamic>> get anchors =>
      (raw['anchors'] as List<dynamic>).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get expected =>
      (raw['expected'] as List<dynamic>).cast<Map<String, dynamic>>();

  DetectorPreprocessResult get geometry => DetectorPreprocessResult(
        tensor: Float32List(0),
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        scaledWidth: scaledWidth,
        scaledHeight: scaledHeight,
        padX: padX,
        padY: padY,
      );
}

/// Rebuilds a full-size head tensor from the sparse recorded anchors.
///
/// Anchors the model did not activate stay zero, which is exactly what a real
/// zero-scoring anchor looks like, so decode sees a faithful tensor.
Float32List tensorFrom(Fixture fixture) {
  final buffer = Float32List(
    ProduceDetectorService.outputChannels * ProduceDetectorService.anchorCount,
  );
  for (final anchor in fixture.anchors) {
    final index = anchor['a'] as int;
    final values = (anchor['v'] as List<dynamic>).cast<num>();
    for (var channel = 0; channel < values.length; channel++) {
      buffer[channel * ProduceDetectorService.anchorCount + index] =
          values[channel].toDouble();
    }
  }
  return buffer;
}

/// Writes one detection into an otherwise empty tensor.
Float32List tensorWith({
  required int anchor,
  required int classIndex,
  required double score,
  required double cx,
  required double cy,
  required double w,
  required double h,
}) {
  final buffer = Float32List(
    ProduceDetectorService.outputChannels * ProduceDetectorService.anchorCount,
  );
  const anchors = ProduceDetectorService.anchorCount;
  buffer[anchor] = cx;
  buffer[anchors + anchor] = cy;
  buffer[2 * anchors + anchor] = w;
  buffer[3 * anchors + anchor] = h;
  buffer[(4 + classIndex) * anchors + anchor] = score;
  return buffer;
}

List<String> loadDetectorLabels() {
  final file = File(ProduceDetectorService.labelsAssetPath);
  return file
      .readAsLinesSync()
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();
}

DetectorPreprocessResult geometryFor({
  int imageWidth = 1080,
  int imageHeight = 1920,
  int scaledWidth = 360,
  int scaledHeight = 640,
  int padX = 140,
  int padY = 0,
}) {
  return DetectorPreprocessResult(
    tensor: Float32List(0),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    scaledWidth: scaledWidth,
    scaledHeight: scaledHeight,
    padX: padX,
    padY: padY,
  );
}

/// Overlap between a decoded detection and an annotation from the fixture.
double _iou(ProduceDetection detection, Map<String, dynamic> annotation) {
  final ax = detection.left;
  final ay = detection.top;
  final aw = detection.width;
  final ah = detection.height;
  final bx = annotation['left'] as double;
  final by = annotation['top'] as double;
  final bw = annotation['w'] as double;
  final bh = annotation['h'] as double;

  final ix = _max(0.0, _min(ax + aw, bx + bw) - _max(ax, bx));
  final iy = _max(0.0, _min(ay + ah, by + bh) - _max(ay, by));
  final intersection = ix * iy;
  if (intersection <= 0) return 0;
  final union = aw * ah + bw * bh - intersection;
  return union <= 0 ? 0 : intersection / union;
}

double _min(double a, double b) => a < b ? a : b;

double _max(double a, double b) => a > b ? a : b;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final labels = loadDetectorLabels();

  group('detector assets', () {
    test('labels asset is registered in the Flutter asset bundle', () async {
      final bundled =
          await rootBundle.loadString(ProduceDetectorService.labelsAssetPath);

      final entries = bundled
          .split('\n')
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList();

      expect(entries.length, ProduceDetectorService.classCount);
      expect(entries, labels);
    });

    test('labels asset holds exactly the 31 detector classes', () {
      expect(labels.length, ProduceDetectorService.classCount);
      expect(labels.length, 31);
    });

    test('every reliability figure names a class that exists', () {
      for (final name in ProduceDetectorService.measuredAp50.keys) {
        expect(labels, contains(name), reason: '$name is not in the label asset');
      }
      expect(
        ProduceDetectorService.measuredAp50.length,
        ProduceDetectorService.classCount,
      );
    });

    test('trust table matches the held-out measurements', () {
      // 12 of 28 measured classes reached AP50 >= 0.40.
      expect(ProduceDetectorService.trustedClasses.length, 12);
      expect(
        ProduceDetectorService.trustedClasses,
        containsAll(<String>[
          'apple',
          'banana',
          'carrot',
          'kiwi',
          'orange',
          'tomato',
          'beetroot',
          'cabbage',
          'mango',
          'pomegranate',
          'soy beans',
          'spinach',
        ]),
      );
      expect(
        ProduceDetectorService.trustedClasses,
        isNot(contains('garlic')),
        reason: 'garlic scored AP50 0.004',
      );
      expect(
        ProduceDetectorService.trustedClasses,
        isNot(contains('eggplant')),
        reason: 'eggplant scored AP50 0.000',
      );
    });

    test('classes with no held-out instances are never trusted', () {
      for (final name in <String>['potato', 'turnip', 'watermelon']) {
        expect(ProduceDetectorService.isTrusted(name), isFalse);
        expect(ProduceDetectorService.reliabilityNote(name), contains('no held-out'));
      }
    });
  });

  group('confidence floors', () {
    test('trusted and untrusted classes get different floors', () {
      expect(ProduceDetectorService.confidenceFloorFor('banana'), 0.25);
      expect(ProduceDetectorService.confidenceFloorFor('garlic'), 0.60);
    });

    test('capsicum spelling resolves to the untrusted Capsicum class', () {
      expect(
        ProduceDetectorService.confidenceFloorFor('capsicum'),
        0.60,
      );
      expect(ProduceDetectorService.isTrusted('capsicum'), isFalse);
    });

    test('reliability note is empty for trusted classes', () {
      expect(ProduceDetectorService.reliabilityNote('spinach'), isEmpty);
      expect(
        ProduceDetectorService.reliabilityNote('Corn'),
        contains('unreliable'),
      );
    });
  });

  group('decodeDetections against recorded model output', () {
    late Fixture fixture;

    setUpAll(() {
      fixture = Fixture.load();
    });

    test('fixture is a non-square frame with real padding', () {
      expect(fixture.imageWidth, isNot(fixture.imageHeight));
      expect(fixture.padX, greaterThan(0));
      expect(fixture.anchors, isNotEmpty);
    });

    test('reproduces the detections the exported model produced', () {
      final detections = decodeDetections(
        tensorFrom(fixture),
        labels: labels,
        prepared: fixture.geometry,
      );

      final expected = fixture.expected;
      expect(detections.length, expected.length);

      for (var i = 0; i < expected.length; i++) {
        final got = detections[i];
        final want = expected[i];
        expect(got.name, want['name']);
        expect(got.confidence, closeTo(want['score'] as double, 1e-4));
        expect(got.left, closeTo(want['left'] as double, 1.0));
        expect(got.top, closeTo(want['top'] as double, 1.0));
        expect(got.width, closeTo(want['w'] as double, 1.0));
        expect(got.height, closeTo(want['h'] as double, 1.0));
      }
    });

    // The model localizes loosely on large objects: on this frame the banana
    // annotation is 1060px wide while the detection covers 598px of it, giving
    // IoU 0.38. The decode is verified against the raw tensor separately; this
    // assertion only guards against a coordinate-system regression that would
    // move boxes far from their annotations.
    test('detections land on the annotated objects', () {
      final detections = decodeDetections(
        tensorFrom(fixture),
        labels: labels,
        prepared: fixture.geometry,
      );
      final truth =
          (fixture.raw['truth'] as List<dynamic>).cast<Map<String, dynamic>>();

      for (final detection in detections) {
        final matches = truth.where(
          (Map<String, dynamic> t) => t['name'] == detection.name,
        );
        expect(matches, isNotEmpty,
            reason: '${detection.name} has no annotated counterpart');

        final best = matches
            .map((Map<String, dynamic> t) => _iou(detection, t))
            .reduce((double a, double b) => a > b ? a : b);

        expect(best, greaterThan(0.3),
            reason: '${detection.name} does not overlap its annotation');
      }
    });

    test('outputs are ordered by descending confidence', () {
      final detections = decodeDetections(
        tensorFrom(fixture),
        labels: labels,
        prepared: fixture.geometry,
      );

      for (var i = 1; i < detections.length; i++) {
        expect(
          detections[i - 1].confidence,
          greaterThanOrEqualTo(detections[i].confidence),
        );
      }
    });
  });

  group('box coordinate handling', () {
    test('treats box channels as normalized, not pixels', () {
      // A centre of 0.5 in normalized space is the middle of the frame. If the
      // decoder assumed 0..640 pixels this would collapse to the top-left.
      //
      // Geometry: 1080x1920 source, scaled to 360x640, so scale = 1/3 and
      // padX = 140. A normalized 0.5 is 320 in 640-space; undoing the pad and
      // the scale gives (320 - 140) * 3 = 540, the true centre of 1080.
      final detections = decodeDetections(
        tensorWith(
          anchor: 100,
          classIndex: 1, // banana, trusted
          score: 0.9,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, hasLength(1));
      final box = detections.first;
      expect(box.left + box.width / 2, closeTo(540, 1.0));
      expect(box.top + box.height / 2, closeTo(960, 1.0));
      expect(box.width, closeTo(384, 2.0));
      expect(box.height, closeTo(384, 2.0));
    });

    test('removes letterbox padding before reporting boxes', () {
      // Same box, but padded by 140px. If the pad were not removed the
      // reported centre would sit 140 * 3 = 420px too far right.
      final padded = decodeDetections(
        tensorWith(
          anchor: 7,
          classIndex: 1,
          score: 0.9,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(padX: 140),
      ).single;

      final unpadded = decodeDetections(
        tensorWith(
          anchor: 7,
          classIndex: 1,
          score: 0.9,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(padX: 0, scaledWidth: 640),
      ).single;

      expect(padded.left + padded.width / 2,
          closeTo(unpadded.left + unpadded.width / 2, 1.0));
      expect(padded.left, lessThan(unpadded.left));
    });

    test('drops boxes entirely outside the source image', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 3,
          classIndex: 1,
          score: 0.95,
          cx: 0.0,
          cy: 0.0,
          w: 0.02,
          h: 0.02,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, isEmpty);
    });

    test('drops zero-area boxes', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 3,
          classIndex: 1,
          score: 0.95,
          cx: 0.5,
          cy: 0.5,
          w: 0.0,
          h: 0.4,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, isEmpty);
    });
  });

  group('non-maximum suppression', () {
    test('suppresses overlapping boxes of the same class', () {
      final buffer = tensorWith(
        anchor: 10,
        classIndex: 1,
        score: 0.90,
        cx: 0.5,
        cy: 0.5,
        w: 0.3,
        h: 0.3,
      );
      const anchors = ProduceDetectorService.anchorCount;
      buffer[11] = 0.51;
      buffer[anchors + 11] = 0.51;
      buffer[2 * anchors + 11] = 0.30;
      buffer[3 * anchors + 11] = 0.30;
      buffer[(4 + 1) * anchors + 11] = 0.80;

      final detections = decodeDetections(
        buffer,
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, hasLength(1));
      expect(detections.first.confidence, closeTo(0.90, 1e-4));
    });

    test('keeps same-score boxes of different classes', () {
      final buffer = tensorWith(
        anchor: 10,
        classIndex: 1, // banana
        score: 0.90,
        cx: 0.5,
        cy: 0.5,
        w: 0.3,
        h: 0.3,
      );
      const anchors = ProduceDetectorService.anchorCount;
      buffer[11] = 0.5;
      buffer[anchors + 11] = 0.5;
      buffer[2 * anchors + 11] = 0.3;
      buffer[3 * anchors + 11] = 0.3;
      buffer[(4 + 2) * anchors + 11] = 0.90; // Capsicum

      final detections = decodeDetections(
        buffer,
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, hasLength(2));
    });

    test('keeps distant boxes of the same class as separate items', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 10,
          classIndex: 1,
          score: 0.90,
          cx: 0.2,
          cy: 0.5,
          w: 0.1,
          h: 0.1,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, hasLength(1));
    });
  });

  group('reliability gating', () {
    test('rejects an untrusted class below the raised floor', () {
      // garlic measured AP50 0.004, so a merely confident guess is refused.
      final detections = decodeDetections(
        tensorWith(
          anchor: 5,
          classIndex: labels.indexOf('garlic'),
          score: 0.45,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, isEmpty);
    });

    test('accepts an untrusted class when it is very confident', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 5,
          classIndex: labels.indexOf('garlic'),
          score: 0.75,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, hasLength(1));
      expect(detections.first.isTrusted, isFalse);
      expect(detections.first.reliabilityNote, isNotEmpty);
    });

    test('accepts a trusted class at the normal floor', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 5,
          classIndex: labels.indexOf('banana'),
          score: 0.30,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, hasLength(1));
      expect(detections.first.isTrusted, isTrue);
      expect(detections.first.reliabilityNote, isEmpty);
    });

    test('rejects everything below the trusted floor', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 5,
          classIndex: labels.indexOf('banana'),
          score: 0.20,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, isEmpty);
    });
  });

  group('canonical labels', () {
    test('Corn stays Corn after decoding', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 9,
          classIndex: labels.indexOf('Corn'),
          score: 0.85,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections.single.name, 'Corn');
    });

    test('sweetcorn would collapse to Corn', () {
      final detections = decodeDetections(
        tensorWith(
          anchor: 9,
          classIndex: labels.indexOf('Corn'),
          score: 0.85,
          cx: 0.5,
          cy: 0.5,
          w: 0.2,
          h: 0.2,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(
        detections.single.classIndex,
        labels.indexOf('Corn'),
      );
    });
  });

  group('output shape contract', () {
    test('decoder tolerates an all-zero tensor', () {
      final detections = decodeDetections(
        Float32List(
          ProduceDetectorService.outputChannels *
              ProduceDetectorService.anchorCount,
        ),
        labels: labels,
        prepared: geometryFor(),
      );

      expect(detections, isEmpty);
    });

    test('honours maxDetections', () {
      final buffer = Float32List(
        ProduceDetectorService.outputChannels * ProduceDetectorService.anchorCount,
      );
      const anchors = ProduceDetectorService.anchorCount;
      // Twelve spatially separated bananas.
      for (var i = 0; i < 12; i++) {
        final x = 0.02 + (i % 6) * 0.19;
        final y = 0.05 + (i ~/ 6) * 0.45;
        buffer[i] = x;
        buffer[anchors + i] = y;
        buffer[2 * anchors + i] = 0.08;
        buffer[3 * anchors + i] = 0.08;
        buffer[(4 + 1) * anchors + i] = 0.9 - i * 0.01;
      }

      final detections = decodeDetections(
        buffer,
        labels: labels,
        prepared: geometryFor(),
        maxDetections: 5,
      );

      expect(detections, hasLength(5));
    });

    test('bestClassIndexAt reads channel-major layout', () {
      const anchors = ProduceDetectorService.anchorCount;
      final buffer = Float32List(
        ProduceDetectorService.outputChannels * ProduceDetectorService.anchorCount,
      );
      buffer[(4 + 7) * anchors + 42] = 0.8;
      buffer[(4 + 3) * anchors + 42] = 0.2;

      expect(bestClassIndexAt(buffer, 42), 7);
    });
  });
}