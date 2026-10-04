import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kooked/services/scan_vision_preprocessor.dart';

import '../helpers/fake_scan_vision.dart';

Set<double> _channelValues(
  List<List<List<List<double>>>> tensor,
  int channel,
) {
  final out = <double>{};
  for (final plane in tensor) {
    for (final row in plane) {
      for (final pixel in row) {
        out.add(pixel[channel]);
      }
    }
  }
  return out;
}

void main() {
  group('ScanVisionPreprocessor tensor contract', () {
    test('produces tensor shape [1,224,224,3]', () {
      final result = ScanVisionPreprocessor.fromImage(
        solidImage(120, 130, 140),
      );

      expect(ScanVisionPreprocessor.tensorShape, <int>[1, 224, 224, 3]);
      expect(result.tensor.length, 1);
      expect(result.tensor[0].length, 224);
      expect(result.tensor[0][0].length, 224);
      expect(result.tensor[0][0][0].length, 3);
      expect(result.resizeWidth, 224);
      expect(result.resizeHeight, 224);
      expect(
        result.tensor.length *
            result.tensor[0].length *
            result.tensor[0][0].length *
            result.tensor[0][0][0].length,
        1 * 224 * 224 * 3,
      );
    });

    test('normalizes with ImageNet mean/std', () {
      const r = 255;
      const g = 0;
      const b = 0;
      final result = ScanVisionPreprocessor.fromImage(solidImage(r, g, b));

      expect(ScanVisionPreprocessor.normalizationMean,
          <double>[0.485, 0.456, 0.406]);
      expect(
          ScanVisionPreprocessor.normalizationStd, <double>[0.229, 0.224, 0.225]);

      final pixel = result.tensor[0][0][0];
      expect(pixel[0], closeTo((r / 255.0 - 0.485) / 0.229, 1e-12));
      expect(pixel[1], closeTo((g / 255.0 - 0.456) / 0.224, 1e-12));
      expect(pixel[2], closeTo((b / 255.0 - 0.406) / 0.225, 1e-12));
    });

    test('normalizes mid grey to a positive offset on every channel', () {
      final result = ScanVisionPreprocessor.fromImage(solidImage(128, 128, 128));
      final pixel = result.tensor[0][112][112];

      expect(pixel[0], closeTo((128 / 255.0 - 0.485) / 0.229, 1e-12));
      expect(pixel[1], closeTo((128 / 255.0 - 0.456) / 0.224, 1e-12));
      expect(pixel[2], closeTo((128 / 255.0 - 0.406) / 0.225, 1e-12));
      expect(
        pixel.every((v) => v > 0.0),
        isTrue,
        reason: 'mid grey normalizes above zero for every channel',
      );
    });

    test('emits channels in R, G, B order', () {
      final tensor = ScanVisionPreprocessor.buildTensor(solidImage(10, 20, 30));
      final pixel = tensor[0][64][64];

      expect(pixel[0], closeTo((10 / 255.0 - 0.485) / 0.229, 1e-12),
          reason: 'channel 0 must be red');
      expect(pixel[1], closeTo((20 / 255.0 - 0.456) / 0.224, 1e-12),
          reason: 'channel 1 must be green');
      expect(pixel[2], closeTo((30 / 255.0 - 0.406) / 0.225, 1e-12),
          reason: 'channel 2 must be blue');

      final red =
          ScanVisionPreprocessor.buildTensor(solidImage(255, 0, 0))[0][0][0];
      final blue =
          ScanVisionPreprocessor.buildTensor(solidImage(0, 0, 255))[0][0][0];
      expect(red[0] > red[2], isTrue,
          reason: 'pure red must exceed blue in channel 0');
      expect(blue[2] > blue[0], isTrue,
          reason: 'pure blue must exceed red in channel 2');
    });
  });

  group('ScanVisionPreprocessor crop geometry (unchanged)', () {
    test('centres a square of side min(width, height)', () {
      final file = writeTempPng(40, 20);
      final result = ScanVisionPreprocessor.fromImage(
        img.decodePng(file.readAsBytesSync())!,
      );

      expect(result.imageWidth, 40);
      expect(result.imageHeight, 20);
      expect(result.cropWidth, 20);
      expect(result.cropHeight, 20);
      expect(result.cropX, 10);
      expect(result.cropY, 0);
    });

    test('portrait crops vertically centred', () {
      final result = ScanVisionPreprocessor.fromImage(
        img.Image(width: 30, height: 60),
      );

      expect(result.cropWidth, 30);
      expect(result.cropHeight, 30);
      expect(result.cropX, 0);
      expect(result.cropY, 15);
    });
  });

  group('ScanVisionPreprocessor interpolation', () {
    test('uses bilinear, not the copyResize default', () {
      expect(ScanVisionPreprocessor.resizeInterpolation,
          img.Interpolation.linear);
      expect(
        ScanVisionPreprocessor.resizeInterpolation,
        isNot(img.Interpolation.nearest),
      );
    });

    test('bilinear output matches an explicit bilinear resize and differs from nearest', () {
      final file = writeTempPng(8, 8);
      final source = img.decodePng(file.readAsBytesSync())!;

      final actual = ScanVisionPreprocessor.fromImage(source);

      final bilinearRef = img.copyResize(
        source,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );
      final nearestRef = img.copyResize(
        source,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.nearest,
      );

      final expectedBilinear = ScanVisionPreprocessor.buildTensor(bilinearRef);
      final nearestTensor = ScanVisionPreprocessor.buildTensor(nearestRef);

      expect(actual.interpolation, img.Interpolation.linear);
      expect(actual.tensor, equals(expectedBilinear),
          reason: 'preprocessor output must equal an explicit bilinear resize');
      expect(actual.tensor, isNot(equals(nearestTensor)),
          reason: 'bilinear and nearest must actually differ for this pattern');
    });

    test('bilinear emits strictly more distinct channel values than nearest', () {
      final file = writeTempPng(8, 8);
      final source = img.decodePng(file.readAsBytesSync())!;

      final bilinear = ScanVisionPreprocessor.fromImage(source).tensor;
      final nearest = ScanVisionPreprocessor.buildTensor(
        img.copyResize(
          source,
          width: 224,
          height: 224,
          interpolation: img.Interpolation.nearest,
        ),
      );

      for (var c = 0; c < 3; c++) {
        final bilinearValues = _channelValues(bilinear, c);
        final nearestValues = _channelValues(nearest, c);

        expect(
          bilinearValues.length,
          greaterThan(nearestValues.length),
          reason: 'channel $c: bilinear must blend, creating extra values '
              'beyond the source values nearest can emit',
        );
      }
    });
  });
}