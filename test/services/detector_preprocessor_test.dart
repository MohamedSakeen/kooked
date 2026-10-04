import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kooked/services/detector_preprocessor.dart';

void main() {
  group('DetectorPreprocessor geometry', () {
    test('square image needs no padding', () {
      final result = DetectorPreprocessor.fromImage(
        img.Image(width: 640, height: 640),
      );

      expect(result.scaledWidth, 640);
      expect(result.scaledHeight, 640);
      expect(result.padX, 0);
      expect(result.padY, 0);
      expect(result.scale, closeTo(1.0, 1e-9));
    });

    test('landscape image is height-limited and padded vertically', () {
      final result = DetectorPreprocessor.fromImage(
        img.Image(width: 1280, height: 720),
      );

      expect(result.scaledWidth, 640);
      expect(result.scaledHeight, 360);
      expect(result.padX, 0);
      expect(result.padY, 140);
      expect(result.scale, closeTo(0.5, 1e-9));
    });

    test('portrait image is width-limited and padded horizontally', () {
      final result = DetectorPreprocessor.fromImage(
        img.Image(width: 1080, height: 1920),
      );

      expect(result.scaledWidth, 360);
      expect(result.scaledHeight, 640);
      expect(result.padX, 140);
      expect(result.padY, 0);
      expect(result.scale, closeTo(1 / 3, 1e-9));
    });

    test('aspect ratio is preserved rather than stretched', () {
      final result = DetectorPreprocessor.fromImage(
        img.Image(width: 1080, height: 1920),
      );

      expect(
        result.scaledWidth / result.scaledHeight,
        closeTo(1080 / 1920, 1e-6),
      );
    });

    test('padding stays symmetric for an odd remainder', () {
      final result = DetectorPreprocessor.fromImage(
        img.Image(width: 1000, height: 999),
      );

      final horizontalRemainder = 640 - result.scaledWidth;
      final leftGap = result.padX;
      final rightGap = horizontalRemainder - leftGap;

      expect((leftGap - rightGap).abs(), lessThanOrEqualTo(1));
    });
  });

  group('DetectorPreprocessor tensor', () {
    test('produces a NCHW float32 tensor of the expected size', () {
      final result = DetectorPreprocessor.fromImage(
        img.Image(width: 640, height: 640),
      );

      expect(result.tensor.length, 1 * 3 * 640 * 640);
      expect(result.tensor, isA<Float32List>());
      expect(DetectorPreprocessor.tensorShape, <int>[1, 3, 640, 640]);
      expect(DetectorPreprocessor.tensorDtype, 'float32');
    });

    test('stores channels in NCHW order and scales to 0..1', () {
      const red = 255;
      const green = 0;
      const blue = 128;
      final tensor = DetectorPreprocessor.buildTensor(
        img.Image(width: 4, height: 4)
          ..setPixelRgb(1, 2, red, green, blue),
        0,
        0,
      );

      const plane = 640 * 640;
      const index = 2 * 640 + 1;
      expect(tensor[index], closeTo(1.0, 1e-6));
      expect(tensor[plane + index], closeTo(0.0, 1e-6));
      expect(tensor[2 * plane + index], closeTo(128 / 255, 1e-6));
    });

    test('fills out-of-frame region with mid-grey 114', () {
      final tensor = DetectorPreprocessor.buildTensor(
        img.Image(width: 320, height: 320),
        0,
        0,
      );

      // Bottom-right pixel lies in the padded region.
      const index = 639 * 640 + 639;
      expect(tensor[index], closeTo(114 / 255, 1e-6));
      expect(tensor[640 * 640 + index], closeTo(114 / 255, 1e-6));
      expect(tensor[2 * 640 * 640 + index], closeTo(114 / 255, 1e-6));
    });

    test('writes no value outside 0..1', () {
      final tensor = DetectorPreprocessor.buildTensor(
        img.Image(width: 64, height: 64)
          ..setPixelRgb(0, 0, 255, 255, 255),
        10,
        10,
      );

      for (final value in tensor) {
        expect(value, inInclusiveRange(0.0, 1.0));
      }
    });

    test('applies padding offsets, not just centred padding', () {
      // An 8x8 source at offset (3, 2) occupies x in [3, 11) and y in [2, 10).
      final tensor = DetectorPreprocessor.buildTensor(
        img.Image(width: 8, height: 8),
        3,
        2,
      );

      const plane = 640 * 640;
      int at(int x, int y) => y * 640 + x;

      // Top-left corner of the pasted image.
      expect(tensor[at(3, 2)], closeTo(0.0, 1e-6));
      // Immediately left of and right of the pasted region.
      expect(tensor[at(2, 2)], closeTo(114 / 255, 1e-6));
      expect(tensor[at(11, 2)], closeTo(114 / 255, 1e-6));
      // Immediately below it.
      expect(tensor[at(3, 10)], closeTo(114 / 255, 1e-6));
      // Last pixel inside the pasted region.
      expect(tensor[at(10, 9)], closeTo(0.0, 1e-6));
      expect(tensor[plane + at(2, 2)], closeTo(114 / 255, 1e-6));
    });
  });

  group('DetectorPreprocessor file loading', () {
    test('decodes a PNG from disk', () async {
      final dir = Directory.systemTemp.createTempSync('kooked_detector');
      final file = File('${dir.path}/frame.png');
      file.writeAsBytesSync(img.encodePng(img.Image(width: 320, height: 240)));

      final result = await DetectorPreprocessor.fromFile(file);

      expect(result.imageWidth, 320);
      expect(result.imageHeight, 240);
      expect(result.tensor.length, 1 * 3 * 640 * 640);
    });
  });
}