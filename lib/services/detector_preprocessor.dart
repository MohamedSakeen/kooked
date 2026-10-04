import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Output of detector preprocessing, including the geometry needed to map
/// model-space boxes back onto the original image.
class DetectorPreprocessResult {
  const DetectorPreprocessResult({
    required this.tensor,
    required this.imageWidth,
    required this.imageHeight,
    required this.scaledWidth,
    required this.scaledHeight,
    required this.padX,
    required this.padY,
  });

  /// Model input as flat `[1][3][640][640]` NCHW float data, RGB, divided by
  /// 255 with no mean/std normalization.
  final Float32List tensor;

  final int imageWidth;
  final int imageHeight;

  /// Size of the resized image before padding was added.
  final int scaledWidth;
  final int scaledHeight;

  /// Padding added on the left and top edges, in model pixels.
  final int padX;
  final int padY;

  /// Uniform scale factor applied to the source image.
  double get scale => scaledWidth / imageWidth;
}

/// Turns an image file into the exact tensor the YOLO26n detector expects.
///
/// This deliberately does **not** reuse [ScanVisionPreprocessor]. A YOLO
/// detector needs the whole frame, not a centred crop: cropping throws away
/// the edges of a cluttered counter shot, which is exactly where extra items
/// sit. It also normalizes differently - plain `/255.0`, no ImageNet
/// mean/std - and the output is NCHW rather than NHWC.
class DetectorPreprocessor {
  const DetectorPreprocessor._();

  static const int inputSize = 640;
  static const int channels = 3;
  static const int tensorLength = channels * inputSize * inputSize;

  /// Ultralytics pads letterboxed images with mid-grey.
  static const int padValue = 114;

  static const List<int> tensorShape = <int>[1, channels, inputSize, inputSize];
  static const String tensorDtype = 'float32';

  static const img.Interpolation resizeInterpolation = img.Interpolation.linear;

  static Future<DetectorPreprocessResult> fromFile(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('Image bytes are not a decodable format');
    }
    return fromImage(image);
  }

  static DetectorPreprocessResult fromImage(img.Image image) {
    final scale =
        math.min(inputSize / image.width, inputSize / image.height);
    final scaledWidth = _roundHalfEven(image.width * scale);
    final scaledHeight = _roundHalfEven(image.height * scale);

    // Matches the reference implementation's `round(dx - 0.1)`. The offset
    // keeps padding symmetric for odd remainders.
    final padX = _roundHalfEven((inputSize - scaledWidth) / 2 - 0.1);
    final padY = _roundHalfEven((inputSize - scaledHeight) / 2 - 0.1);

    final resized = img.copyResize(
      image,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: resizeInterpolation,
    );

    return DetectorPreprocessResult(
      tensor: buildTensor(resized, padX, padY),
      imageWidth: image.width,
      imageHeight: image.height,
      scaledWidth: scaledWidth,
      scaledHeight: scaledHeight,
      padX: padX,
      padY: padY,
    );
  }

  /// Builds the NCHW tensor from an already-resized image, padding the
  /// remainder with [padValue].
  static Float32List buildTensor(
    img.Image resized,
    int padX,
    int padY,
  ) {
    final out = Float32List(tensorLength);
    final plane = inputSize * inputSize;

    for (var y = 0; y < inputSize; y++) {
      final srcY = y - padY;
      final rowOut = y * inputSize;
      for (var x = 0; x < inputSize; x++) {
        final srcX = x - padX;
        double r, g, b;
        if (srcX < 0 ||
            srcY < 0 ||
            srcX >= resized.width ||
            srcY >= resized.height) {
          r = g = b = padValue.toDouble();
        } else {
          final pixel = resized.getPixel(srcX, srcY);
          r = pixel.r.toDouble();
          g = pixel.g.toDouble();
          b = pixel.b.toDouble();
        }
        final i = rowOut + x;
        out[i] = r / 255.0;
        out[plane + i] = g / 255.0;
        out[2 * plane + i] = b / 255.0;
      }
    }

    return out;
  }

  /// Rounds half to even, matching Python's `round()`.
  ///
  /// [num.round] rounds halves away from zero, which disagrees with the
  /// training-time geometry on exact `.5` remainders and would shift padding
  /// by a pixel versus what the model was fitted with.
  static int _roundHalfEven(double value) {
    final floor = value.floorToDouble();
    final diff = value - floor;
    if (diff > 0.5) return floor.toInt() + 1;
    if (diff < 0.5) return floor.toInt();
    return floor.toInt().isEven ? floor.toInt() : floor.toInt() + 1;
  }
}