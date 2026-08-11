import 'detection.dart';
import 'detection_result.dart';

/// Decides slim-vs-standard 330 ml cans from the shape of the box, not from
/// what the classifier thought the crop looked like.
///
/// ## Why this exists
///
/// A brand that sells both a standard and a slim 330 ml can is the same
/// product in two physical formats. A standard can is roughly 66 mm wide by
/// 115 mm tall (height / width ~ 1.74); a slim can is roughly 53 mm by
/// 145 mm (~ 2.7). Everything else about them -- the logo, the colour, the
/// finish -- is identical, so *proportion is the only reliable signal*.
///
/// That is exactly the signal the brand classifier cannot see. CLIP-style
/// encoders resize every crop to a square before embedding it, which throws
/// the aspect ratio away: a tall can and a wide can arrive at the encoder
/// looking the same. Measured on a shelf photo holding both formats side by
/// side, the classifier put all ten cans in one class while the boxes
/// separated cleanly:
///
/// | format   | measured h/w  |
/// |----------|---------------|
/// | standard | 1.72 - 1.82   |
/// | slim     | 2.30 - 2.58   |
///
/// The detector's own boxes are tight (0.96+ confidence) and land on the
/// physical ratios, so the format is read straight off them.
///
/// ## The classifier stays brand-only, on purpose
///
/// This rule takes the classifier's plain brand label (`coca-cola`, not a
/// brand+format class it would need retraining to learn) and rewrites it
/// into a format-specific one *only* for brands declared in
/// [dualFormatBrands]. A brand that is not declared is passed through
/// untouched: format only means something where two formats actually exist,
/// and inventing a suffix elsewhere would be a lie. Onboarding a new
/// dual-format brand this way costs one map entry, not a classifier retrain.
class CanShapeRule {
  /// Height / width at or above which a box is a slim can.
  ///
  /// Sits in the empty band between the two measured clusters (1.82 .. 2.30),
  /// so neither cluster is near it. Raise it if standard cans start reading as
  /// slim; lower it for the reverse.
  final double slimAspectRatio;

  /// How many times taller than the shelf's other products a box must be
  /// before this rule declines to force a can format onto it.
  ///
  /// This rule's proportions were measured on 330 ml cans, and nothing else --
  /// a 2-litre bottle of the same brand is tall and narrow too, and can clear
  /// [slimAspectRatio] just as easily, which is exactly what produced a
  /// `coca-cola-slim` label on a 2-litre plastic bottle. Aspect ratio alone
  /// cannot tell the two apart; absolute size can. A 2-litre bottle runs
  /// roughly 2.3 - 2.6x the height of a 330 ml can, while the slim and
  /// standard cans of one shelf photo stayed within about 15% of each other
  /// (225 - 257 px, see the fixture in `can_shape_rule_test.dart`). 1.6 sits
  /// comfortably between the two, so a can is never vetoed by its own
  /// format-mate but a bottle standing among cans is.
  ///
  /// There is no absolute size available from a single crop -- only relative
  /// to whatever else is on the same shelf. When the photo holds nothing else
  /// to compare against, this check has nothing to work with and steps aside;
  /// [shapeClassOf] then judges on aspect ratio alone, same as before.
  final double maxHeightRatioToReference;

  /// Brands sold in both a standard and a slim 330 ml can, mapped to the
  /// (slim, standard) label pair to write onto the detection.
  ///
  /// Pilot entry: `coca-cola`. Extend this map to onboard another dual-format
  /// brand -- no retraining required, since the classifier keeps predicting
  /// the plain brand name either way.
  final Map<String, (String slim, String standard)> dualFormatBrands;

  const CanShapeRule({
    this.slimAspectRatio = 2.05,
    this.maxHeightRatioToReference = 1.6,
    this.dualFormatBrands = const {
      'coca-cola': ('coca-cola-slim', 'coca-cola-standard'),
    },
  });

  /// Whether [className] is a brand this rule arbitrates the format of.
  bool governs(String className) => dualFormatBrands.containsKey(className);

  /// The label [detection]'s proportions imply, or null when the rule declines
  /// to judge -- an unrelated class, or a degenerate box.
  String? shapeClassOf(Detection detection) {
    final pair = dualFormatBrands[detection.className];
    if (pair == null) return null;

    final box = detection.box;
    if (box.width <= 0 || box.height <= 0) return null;

    final (slim, standard) = pair;
    return box.height / box.width >= slimAspectRatio ? slim : standard;
  }

  /// Returns [result] with every dual-format brand re-labelled from its box
  /// shape.
  ///
  /// Cans touching the frame edge keep whatever the classifier said. Their box
  /// is cut off by the crop rather than by the can, so its height understates
  /// the real one and a slim can would read as standard.
  DetectionResult applyTo(DetectionResult result) {
    if (result.isEmpty) return result;

    var changed = false;
    final refined = <Detection>[];
    final detections = result.detections;

    for (var i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final clipped = _touchesFrame(
        detection,
        imageWidth: result.imageWidth,
        imageHeight: result.imageHeight,
      );
      final tooTallForACan =
          !clipped && _isImplausiblyTall(detection, detections, i, result);
      final shapeClass = (clipped || tooTallForACan)
          ? null
          : shapeClassOf(detection);

      if (shapeClass == null || shapeClass == detection.className) {
        refined.add(detection);
      } else {
        refined.add(detection.withClassName(shapeClass));
        changed = true;
      }
    }

    return changed ? result.withDetections(refined) : result;
  }

  /// Whether [detection] is too tall, relative to every other unclipped box
  /// on the same shelf, to plausibly be the same size container -- e.g. a
  /// 2-litre bottle standing among 330 ml cans.
  ///
  /// Declines to veto (`false`) when there is nothing else in the photo to
  /// compare against: a lone product's absolute pixel size carries no
  /// information about which real-world container it is without a reference.
  bool _isImplausiblyTall(
    Detection detection,
    List<Detection> all,
    int index,
    DetectionResult result,
  ) {
    final referenceHeights = <double>[
      for (var j = 0; j < all.length; j++)
        if (j != index &&
            all[j].box.height > 0 &&
            !_touchesFrame(
              all[j],
              imageWidth: result.imageWidth,
              imageHeight: result.imageHeight,
            ))
          all[j].box.height,
    ]..sort();
    if (referenceHeights.isEmpty) return false;

    final medianHeight = referenceHeights[referenceHeights.length ~/ 2];
    return detection.box.height > medianHeight * maxHeightRatioToReference;
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
