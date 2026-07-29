import 'dart:ui' show Rect;

/// An axis-aligned box in the coordinate space of the image it was detected in.
///
/// Roboflow reports boxes as a *centre point* plus width/height, so that is the
/// primary constructor. Edge accessors are derived rather than stored to keep a
/// single source of truth.
class BoundingBox {
  /// Horizontal centre of the box, in source-image pixels.
  final double centerX;

  /// Vertical centre of the box, in source-image pixels.
  final double centerY;

  /// Full width of the box, in source-image pixels.
  final double width;

  /// Full height of the box, in source-image pixels.
  final double height;

  const BoundingBox({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });

  /// Builds a box from its edges instead of its centre.
  factory BoundingBox.fromLTWH(
    double left,
    double top,
    double width,
    double height,
  ) {
    return BoundingBox(
      centerX: left + width / 2,
      centerY: top + height / 2,
      width: width,
      height: height,
    );
  }

  double get left => centerX - width / 2;
  double get top => centerY - height / 2;
  double get right => centerX + width / 2;
  double get bottom => centerY + height / 2;

  /// Area in square pixels. Never negative -- a malformed box reports zero
  /// rather than poisoning a Share-of-Shelf sum with a negative contribution.
  double get area {
    if (width <= 0 || height <= 0) return 0;
    return width * height;
  }

  /// Projects this box from source-image pixels into a rendered widget of
  /// [displaySize], given the image was [imageWidth] x [imageHeight].
  ///
  /// Assumes the image is drawn with `BoxFit.contain`, which is what
  /// [DetectionOverlay] uses, so the same letterboxing maths applies to both.
  Rect toDisplayRect({
    required double imageWidth,
    required double imageHeight,
    required double displayWidth,
    required double displayHeight,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) return Rect.zero;

    // BoxFit.contain: uniform scale, letterboxed on the shorter axis.
    final scale = (displayWidth / imageWidth) < (displayHeight / imageHeight)
        ? displayWidth / imageWidth
        : displayHeight / imageHeight;

    final offsetX = (displayWidth - imageWidth * scale) / 2;
    final offsetY = (displayHeight - imageHeight * scale) / 2;

    return Rect.fromLTWH(
      left * scale + offsetX,
      top * scale + offsetY,
      width * scale,
      height * scale,
    );
  }

  @override
  String toString() =>
      'BoundingBox(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)})';
}
