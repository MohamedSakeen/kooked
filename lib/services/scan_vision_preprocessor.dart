import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Output of the preprocessing stage, including everything needed to describe
/// how the model input was produced.
class ScanVisionPreprocessResult {
  const ScanVisionPreprocessResult({
    required this.tensor,
    required this.imageWidth,
    required this.imageHeight,
    required this.cropX,
    required this.cropY,
    required this.cropWidth,
    required this.cropHeight,
    required this.resizeWidth,
    required this.resizeHeight,
    required this.interpolation,
  });

  /// Model input as `[1][224][224][3]`, RGB order, ImageNet normalized.
  final List<List<List<List<double>>>> tensor;

  final int imageWidth;
  final int imageHeight;

  final int cropX;
  final int cropY;
  final int cropWidth;
  final int cropHeight;

  final int resizeWidth;
  final int resizeHeight;

  final img.Interpolation interpolation;
}

/// Turns an image file into the exact tensor the bundled classifier expects.
///
/// Crop geometry is intentionally unchanged from the previous implementation:
/// a centred square of side `min(width, height)`. Only the resize
/// interpolation mode was made explicit.
class ScanVisionPreprocessor {
  const ScanVisionPreprocessor._();

  static const int inputSize = 224;
  static const int channels = 3;

  static const List<int> tensorShape = <int>[1, inputSize, inputSize, channels];

  /// ImageNet per-channel mean used by the original implementation.
  static const List<double> normalizationMean = <double>[
    0.485,
    0.456,
    0.406,
  ];

  /// ImageNet per-channel standard deviation.
  static const List<double> normalizationStd = <double>[
    0.229,
    0.224,
    0.225,
  ];

  /// The bundled model consumes float32. Dart builds float64 doubles here and
  /// the FFI boundary narrows them, which is lossless for this value range.
  static const String tensorDtype = 'float32';

  /// `package:image` names bilinear resampling [img.Interpolation.linear].
  ///
  /// The previous code relied on `copyResize`'s default, which is
  /// [img.Interpolation.nearest].
  static const img.Interpolation resizeInterpolation = img.Interpolation.linear;

  static Future<ScanVisionPreprocessResult> fromFile(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('Image bytes are not a decodable format');
    }
    return fromImage(image);
  }

  static ScanVisionPreprocessResult fromImage(img.Image image) {
    final int cropSize = math.min(image.width, image.height).toInt();
    final cropX = (image.width - cropSize) ~/ 2;
    final cropY = (image.height - cropSize) ~/ 2;

    final cropped = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropSize,
      height: cropSize,
    );

    final resized = img.copyResize(
      cropped,
      width: inputSize,
      height: inputSize,
      interpolation: resizeInterpolation,
    );

    return ScanVisionPreprocessResult(
      tensor: buildTensor(resized),
      imageWidth: image.width,
      imageHeight: image.height,
      cropX: cropX,
      cropY: cropY,
      cropWidth: cropSize,
      cropHeight: cropSize,
      resizeWidth: inputSize,
      resizeHeight: inputSize,
      interpolation: resizeInterpolation,
    );
  }

  /// Normalizes an already-resized RGB image into `[1][224][224][3]`.
  ///
  /// Channel order is R, G, B to match the model's [input_shape] last axis.
  static List<List<List<List<double>>>> buildTensor(img.Image resized) {
    final mean = normalizationMean;
    final std = normalizationStd;

    return <List<List<List<double>>>>[
      List<List<List<double>>>.generate(
        inputSize,
        (int y) => List<List<double>>.generate(
          inputSize,
          (int x) {
            final pixel = resized.getPixel(x, y);
            return <double>[
              (pixel.r / 255.0 - mean[0]) / std[0],
              (pixel.g / 255.0 - mean[1]) / std[1],
              (pixel.b / 255.0 - mean[2]) / std[2],
            ];
          },
        ),
      ),
    ];
  }
}