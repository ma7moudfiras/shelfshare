import 'detection.dart';
import 'detection_result.dart';

/// Decides slim-vs-standard 330 ml cans from the shape of the box, not from
/// what the classifier thought the crop looked like.
///
/// ## Why this exists
///
/// The two SKUs are the same product in two can formats. A standard 330 ml can
/// is roughly 66 mm wide by 115 mm tall (height / width ~ 1.74); a sleek 330 ml
/// can is roughly 53 mm by 145 mm (~ 2.7). Everything else about them -- the
/// logo, the colour, the finish -- is identical, so *proportion is the only
/// reliable signal*.
///
/// That is exactly the signal the visual-search classifier cannot see. CLIP
/// resizes every crop to a square 224x224 before embedding it, which throws the
/// aspect ratio away: a tall can and a wide can arrive at the encoder looking
/// the same. Measured on a shelf photo holding both formats side by side, the
/// classifier put all ten cans in one class while the boxes separated cleanly:
///
/// | format   | measured h/w  |
/// |----------|---------------|
/// | standard | 1.72 - 1.82   |
/// | sleek    | 2.30 - 2.58   |
///
/// The detector's own boxes are tight (0.96+ confidence) and land on the
/// physical ratios, so the split is read straight off them.
///
/// ## What it does not do
///
/// This rule only ever swaps one 330 ml label for the other. Any class it does
/// not recognise is passed through untouched -- deciding *which product* a can
/// is remains the classifier's job, and shape says nothing about brand.
class CanShapeRule {
  /// Height / width at or above which a box is a sleek can.
  ///
  /// Sits in the empty band between the two measured clusters (1.82 .. 2.30),
  /// so neither cluster is near it. Raise it if standard cans start reading as
  /// sleek; lower it for the reverse.
  final double slimAspectRatio;

  /// Label written onto boxes taller than [slimAspectRatio].
  final String slimClass;

  /// Label written onto boxes shorter than [slimAspectRatio].
  final String fatClass;

  const CanShapeRule({
    this.slimAspectRatio = 2.05,
    this.slimClass = 'coca-330-slim',
    this.fatClass = 'coca-330-fat',
  });

  /// Whether [className] is one of the two labels this rule arbitrates between.
  bool governs(String className) =>
      className == slimClass || className == fatClass;

  /// The label [detection]'s proportions imply, or null when the rule declines
  /// to judge -- an unrelated class, or a degenerate box.
  String? shapeClassOf(Detection detection) {
    if (!governs(detection.className)) return null;

    final box = detection.box;
    if (box.width <= 0 || box.height <= 0) return null;

    return box.height / box.width >= slimAspectRatio ? slimClass : fatClass;
  }

  /// Returns [result] with every 330 ml can re-labelled from its box shape.
  ///
  /// Cans touching the frame edge keep whatever the classifier said. Their box
  /// is cut off by the crop rather than by the can, so its height understates
  /// the real one and a sleek can would read as standard.
  DetectionResult applyTo(DetectionResult result) {
    if (result.isEmpty) return result;

    var changed = false;
    final refined = <Detection>[];

    for (final detection in result.detections) {
      final clipped = _touchesFrame(
        detection,
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
      );
      final shapeClass = clipped ? null : shapeClassOf(detection);

      if (shapeClass == null || shapeClass == detection.className) {
        refined.add(detection);
      } else {
        refined.add(detection.withClassName(shapeClass));
        changed = true;
      }
    }

    return changed ? result.withDetections(refined) : result;
  }

  /// Whether the box runs into the edge of the photo, meaning the object is
  /// only partly visible and its measured size is a lower bound.
  ///
  /// Unknown image dimensions mean the check cannot be made; the box is treated
  /// as fully visible rather than silently opting every detection out.
  bool _touchesFrame(
    Detection detection, {
    required double imageWidth,
    required double imageHeight,
  }) {
    if (imageWidth <= 0 || imageHeight <= 0) return false;

    const tolerance = 2.0;
    final box = detection.box;
    return box.left <= tolerance ||
        box.top <= tolerance ||
        box.right >= imageWidth - tolerance ||
        box.bottom >= imageHeight - tolerance;
  }
}
