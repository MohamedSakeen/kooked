import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:kooked/services/local_vision_service.dart';

/// Deterministic [ScanTensorRunner] so SUCCESS / EMPTY / EXECUTION-FAILED can
/// be exercised without the native TFLite library.
class FakeTensorRunner implements ScanTensorRunner {
  FakeTensorRunner(this.probabilities);

  /// Target class probabilities; softmax(log(p)) == p, so these are the exact
  /// confidences the service will compute.
  final List<double> probabilities;

  Object? errorOnRun;
  int runCount = 0;
  List<Object?>? lastInput;

  @override
  void run(List<Object?> input, List<Object?> output) {
    runCount++;
    lastInput = input;
    if (errorOnRun != null) {
      throw errorOnRun!;
    }
    final out = output.first as List<double>;
    final logits = _logitsFromProbabilities(probabilities);
    for (var i = 0; i < out.length && i < logits.length; i++) {
      out[i] = logits[i];
    }
  }

  @override
  void close() {}

  static List<double> _logitsFromProbabilities(List<double> weights) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    return weights.map((v) => math.log(v / total)).toList();
  }
}

/// Four produce labels, enough to exercise ranking and the secondary gate.
const List<String> testLabels = <String>['apple', 'banana', 'carrot', 'turnip'];

/// Ten labels, so a distribution can be built whose maximum stays below the
/// 0.25 threshold. With only four classes the maximum can never drop below 0.25.
const List<String> spreadLabels = <String>[
  'apple',
  'banana',
  'carrot',
  'turnip',
  'onion',
  'garlic',
  'potato',
  'lemon',
  'lime',
  'pepper',
];

/// Sums to 1.0 with a maximum of 0.24, i.e. below the 0.25 threshold.
const List<double> spreadProbabilities = <double>[
  0.09, 0.24, 0.09, 0.09, 0.09, 0.09, 0.07, 0.07, 0.07, 0.10,
];

/// Sums to 1.0 with a maximum of 0.26, i.e. just above the 0.25 threshold.
const List<double> justAboveThresholdProbabilities = <double>[
  0.24, 0.26, 0.25, 0.25,
];

/// The shipped 36-label vocabulary, in asset order.
///
/// Mirrors `assets/models/food_labels.txt` so tests exercise the real
/// index-to-label mapping rather than a stand-in.
const List<String> produceLabels = <String>[
  'apple',
  'banana',
  'beetroot',
  'bell pepper',
  'cabbage',
  'capsicum',
  'carrot',
  'cauliflower',
  'chilli pepper',
  'corn',
  'cucumber',
  'eggplant',
  'garlic',
  'ginger',
  'grapes',
  'jalepeno',
  'kiwi',
  'lemon',
  'lettuce',
  'mango',
  'onion',
  'orange',
  'paprika',
  'pear',
  'peas',
  'pineapple',
  'pomegranate',
  'potato',
  'raddish',
  'soy beans',
  'spinach',
  'sweetcorn',
  'sweetpotato',
  'tomato',
  'turnip',
  'watermelon',
];

/// Builds a full 36-way distribution from a sparse {index: probability} map,
/// distributing the remainder evenly across every other class.
///
/// The result sums to 1.0, and `exp(normalised)` recovers the requested
/// probabilities exactly, because [FakeTensorRunner] converts probabilities to
/// logits with `log(p / total)`.
List<double> produceDistribution(Map<int, double> peaks) {
  const n = 36;
  final out = List<double>.filled(n, 0.0);
  final peakTotal = peaks.values.fold<double>(0, (a, b) => a + b);
  if (peakTotal > 1.0) {
    throw ArgumentError.value(peaks, 'peaks', 'peaks must sum to at most 1.0');
  }
  final rest = (1.0 - peakTotal) / (n - peaks.length);
  for (var i = 0; i < n; i++) {
    out[i] = peaks.containsKey(i) ? peaks[i]! : rest;
  }
  return out;
}

/// Writes a temporary PNG with a deterministic per-pixel colour pattern.
File writeTempPng(
  int width,
  int height, {
  int Function(int x, int y)? channelFor,
  String name = 'sample.png',
}) {
  final dir = Directory.systemTemp.createTempSync('kooked_scan_test');
  final image = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (channelFor == null) {
        image.setPixelRgb(x, y, x * 7 % 256, y * 11 % 256, (x + y) * 5 % 256);
      } else {
        final value = channelFor(x, y);
        image.setPixelRgb(x, y, value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF);
      }
    }
  }

  final file = File('${dir.path}${Platform.pathSeparator}$name');
  file.writeAsBytesSync(img.encodePng(image));
  return file;
}

/// A solid-colour 224x224 image, for tensor/normalization assertions.
img.Image solidImage(int r, int g, int b, {int size = 224}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}