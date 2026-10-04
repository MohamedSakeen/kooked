import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws detection boxes over a captured photo.
///
/// The photo is laid out with [BoxFit.cover], so it is scaled up until it fills
/// the widget and the overflow is cropped symmetrically from both sides. Boxes
/// are therefore mapped through that same scale-and-centre transform rather
/// than stretched to the widget bounds — stretching would misplace every box on
/// any frame whose aspect ratio differs from the widget's.
class DetectionOverlayPainter extends CustomPainter {
  const DetectionOverlayPainter({
    required this.boxes,
    required this.imageSize,
  });

  /// Boxes normalized to 0..1 of the source image.
  final List<Rect> boxes;

  /// Source image dimensions in pixels.
  final Size imageSize;

  /// Maps a box from normalized source space into [viewport] under
  /// [BoxFit.cover].
  ///
  /// Exposed for testing: this transform is where an overlay silently drifts.
  static Rect mapCover(Rect normalized, Size imageSize, Size viewport) {
    final double scale = math.max(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
    final double drawnWidth = imageSize.width * scale;
    final double drawnHeight = imageSize.height * scale;
    final double offsetX = (viewport.width - drawnWidth) / 2;
    final double offsetY = (viewport.height - drawnHeight) / 2;

    return Rect.fromLTWH(
      offsetX + normalized.left * drawnWidth,
      offsetY + normalized.top * drawnHeight,
      normalized.width * drawnWidth,
      normalized.height * drawnHeight,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = Colors.black.withValues(alpha: 0.55);
    final Paint box = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;

    for (final Rect normalized in boxes) {
      final Rect rect = mapCover(normalized, imageSize, size);
      canvas.drawRect(rect, outline);
      canvas.drawRect(rect, box);
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    if (oldDelegate.imageSize != imageSize) return true;
    if (oldDelegate.boxes.length != boxes.length) return true;
    for (var i = 0; i < boxes.length; i++) {
      if (oldDelegate.boxes[i] != boxes[i]) return true;
    }
    return false;
  }
}