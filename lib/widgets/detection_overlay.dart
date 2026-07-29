import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../models/detection_result.dart';

/// Assigns each class label a stable, distinguishable colour.
///
/// Keyed on the label text so a class keeps its colour across captures, which
/// makes the overlay readable when comparing two shelves.
class DetectionPalette {
  const DetectionPalette._();

  static const List<Color> _colors = [
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFB8C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF00ACC1), // cyan
    Color(0xFFFDD835), // yellow
    Color(0xFF6D4C41), // brown
  ];

  /// Stable colour for [className].
  static Color forClass(String className) {
    if (className.isEmpty) return _colors.first;
    // hashCode is stable within a run; abs() guards the negative case.
    return _colors[className.hashCode.abs() % _colors.length];
  }
}

/// Paints bounding boxes and labels over the captured image.
///
/// Boxes arrive in source-image pixel coordinates and are projected into widget
/// space by [BoundingBox.toDisplayRect], which mirrors the `BoxFit.contain`
/// letterboxing the image itself is drawn with.
class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final double imageWidth;
  final double imageHeight;

  /// Hides boxes below this confidence. 0 shows everything.
  final double minConfidence;

  const DetectionPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    this.minConfidence = 0,
  });

  static const double _strokeWidth = 2.5;
  static const double _labelFontSize = 12;
  static const double _labelPaddingX = 5;
  static const double _labelPaddingY = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    for (final detection in detections) {
      if (detection.confidence < minConfidence) continue;

      final rect = detection.box.toDisplayRect(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        displayWidth: size.width,
        displayHeight: size.height,
      );
      if (rect.isEmpty) continue;

      final color = DetectionPalette.forClass(detection.className);
      _paintBox(canvas, rect, color);
      _paintLabel(canvas, rect, size, detection, color);
    }
  }

  void _paintBox(Canvas canvas, Rect rect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = color,
    );
  }

  void _paintLabel(
    Canvas canvas,
    Rect rect,
    Size size,
    Detection detection,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: detection.displayLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: _labelFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final chipWidth = painter.width + _labelPaddingX * 2;
    final chipHeight = painter.height + _labelPaddingY * 2;

    // Prefer sitting the chip above the box; drop it inside when there is no
    // room at the top, so labels on top-edge detections stay on screen.
    var chipTop = rect.top - chipHeight;
    if (chipTop < 0) chipTop = rect.top;

    // Keep the chip within the right edge of the canvas.
    var chipLeft = rect.left;
    if (chipLeft + chipWidth > size.width) {
      chipLeft = (size.width - chipWidth).clamp(0.0, size.width);
    }

    final chip = Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, const Radius.circular(3)),
      Paint()..color = color,
    );
    painter.paint(canvas, Offset(chip.left + _labelPaddingX, chip.top + _labelPaddingY));
  }

  @override
  bool shouldRepaint(covariant DetectionPainter old) {
    return old.detections != detections ||
        old.imageWidth != imageWidth ||
        old.imageHeight != imageHeight ||
        old.minConfidence != minConfidence;
  }
}

/// The captured image with detection boxes drawn on top of it.
class DetectionOverlay extends StatelessWidget {
  /// Raw bytes of the image the detections refer to.
  final Uint8List imageBytes;

  /// Detections to draw. When null or empty, only the image is shown.
  final DetectionResult? result;

  final double minConfidence;

  const DetectionOverlay({
    super.key,
    required this.imageBytes,
    this.result,
    this.minConfidence = 0,
  });

  @override
  Widget build(BuildContext context) {
    final result = this.result;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(imageBytes, fit: BoxFit.contain),
            if (result != null && result.isNotEmpty)
              CustomPaint(
                painter: DetectionPainter(
                  detections: result.detections,
                  imageWidth: result.imageWidth,
                  imageHeight: result.imageHeight,
                  minConfidence: minConfidence,
                ),
              ),
          ],
        );
      },
    );
  }
}
