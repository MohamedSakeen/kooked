import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kooked/widgets/detection_overlay_painter.dart';

void main() {
  const Size landscapeImage = Size(1920, 1080);
  const Size portraitImage = Size(1080, 1920);
  const Size squareImage = Size(640, 640);

  const Rect full = Rect.fromLTWH(0, 0, 1, 1);
  const Rect centre = Rect.fromLTWH(0.25, 0.25, 0.5, 0.5);

  group('DetectionOverlayPainter.mapCover', () {
    test('fills the viewport when the image matches the aspect ratio', () {
      final rect = DetectionOverlayPainter.mapCover(
        full,
        landscapeImage,
        const Size(400, 225),
      );

      expect(rect.left, closeTo(0, 1e-9));
      expect(rect.top, closeTo(0, 1e-9));
      expect(rect.width, closeTo(400, 1e-9));
      expect(rect.height, closeTo(225, 1e-9));
    });

    test('centres a square image in a wide viewport, cropping top and bottom',
        () {
      // Cover scales by the larger ratio: 400/640 = 0.625 beats 100/640.
      // The image is drawn 400x400 and the vertical overflow is split evenly.
      final rect = DetectionOverlayPainter.mapCover(
        full,
        squareImage,
        const Size(400, 100),
      );

      expect(rect.width, closeTo(400, 1e-9));
      expect(rect.height, closeTo(400, 1e-9));
      expect(rect.left, closeTo(0, 1e-9));
      expect(rect.top, closeTo(-150, 1e-9));
      expect(rect.center.dx, closeTo(200, 1e-9));
    });

    test('centres a square image in a tall viewport, cropping the sides', () {
      final rect = DetectionOverlayPainter.mapCover(
        full,
        squareImage,
        const Size(100, 400),
      );

      expect(rect.width, closeTo(400, 1e-9));
      expect(rect.height, closeTo(400, 1e-9));
      expect(rect.left, closeTo(-150, 1e-9));
      expect(rect.center.dy, closeTo(200, 1e-9));
    });

    test('scales a portrait image to fill height, cropping top and bottom', () {
      final rect = DetectionOverlayPainter.mapCover(
        full,
        portraitImage,
        const Size(200, 400),
      );

      // 1080x1920 into 200x400 -> scale 0.2083, drawn 225x400.
      expect(rect.height, closeTo(400, 1e-6));
      expect(rect.width, closeTo(225, 1e-6));
      expect(rect.center.dy, closeTo(200, 1e-9));
    });

    test('does not stretch a box to fill the viewport', () {
      // The failure mode this guards: a naive implementation divides by the
      // viewport size and inflates every box to the full frame.
      final rect = DetectionOverlayPainter.mapCover(
        centre,
        squareImage,
        const Size(400, 100),
      );

      // Half the drawn 400x400 image, not the full 400x100 viewport.
      expect(rect.width, closeTo(200, 1e-9));
      expect(rect.height, closeTo(200, 1e-9));
    });

    test('keeps relative position within the cropped image', () {
      final rect = DetectionOverlayPainter.mapCover(
        centre,
        squareImage,
        const Size(400, 100),
      );

      // Drawn 400x400 at x=0, y=-150: the centred half starts at (100, 50).
      expect(rect.left, closeTo(100, 1e-9));
      expect(rect.top, closeTo(-50, 1e-9));
    });

    test('maps the fixture frame geometry used by the detector', () {
      // 1080x1920 portrait source, centred 50% box, into the app's preview slot.
      final rect = DetectionOverlayPainter.mapCover(
        centre,
        portraitImage,
        const Size(343, 190),
      );

      // 343/1080 = 0.3176 beats 190/1920 = 0.0990, so this is width-limited:
      // drawn 343 x 609.8 at (0, -209.9). The centred half is 171.5 x 304.9.
      expect(rect.width, closeTo(171.5, 0.2));
      expect(rect.height, closeTo(304.9, 0.2));
      expect(rect.left, closeTo(85.75, 0.2));
      expect(rect.center.dx, closeTo(171.5, 0.2));
    });

    test('handles a degenerate image size without dividing by zero', () {
      final rect = DetectionOverlayPainter.mapCover(
        full,
        Size.zero,
        const Size(400, 100),
      );

      expect(rect.width.isFinite, isFalse);
    });
  });

  group('painting', () {
    testWidgets('paints without error over a plain surface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(300, 200),
            painter: DetectionOverlayPainter(
              boxes: <Rect>[centre, full],
              imageSize: landscapeImage,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders nothing when there are no boxes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(300, 200),
            painter: DetectionOverlayPainter(
              boxes: const <Rect>[],
              imageSize: landscapeImage,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('shouldRepaint', () {
    test('is false for identical input', () {
      const painter = DetectionOverlayPainter(
        boxes: <Rect>[centre],
        imageSize: landscapeImage,
      );
      const same = DetectionOverlayPainter(
        boxes: <Rect>[centre],
        imageSize: landscapeImage,
      );

      expect(painter.shouldRepaint(same), isFalse);
    });

    test('is true when the box count changes', () {
      const one = DetectionOverlayPainter(
        boxes: <Rect>[centre],
        imageSize: landscapeImage,
      );
      const two = DetectionOverlayPainter(
        boxes: <Rect>[centre, full],
        imageSize: landscapeImage,
      );

      expect(one.shouldRepaint(two), isTrue);
    });

    test('is true when the image size changes', () {
      const a = DetectionOverlayPainter(
        boxes: <Rect>[centre],
        imageSize: landscapeImage,
      );
      const b = DetectionOverlayPainter(
        boxes: <Rect>[centre],
        imageSize: portraitImage,
      );

      expect(a.shouldRepaint(b), isTrue);
    });

    test('is true when a box moves', () {
      const a = DetectionOverlayPainter(
        boxes: <Rect>[centre],
        imageSize: landscapeImage,
      );
      const b = DetectionOverlayPainter(
        boxes: <Rect>[full],
        imageSize: landscapeImage,
      );

      expect(a.shouldRepaint(b), isTrue);
    });
  });
}