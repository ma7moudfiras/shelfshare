import 'detection_result.dart';

/// A cheap, post-capture sanity check on a shelf photo's own detection
/// result -- catches a shot taken from too far away before the rep saves it.
///
/// ## Why this, and not a live on-device guide
///
/// A real-time "move closer / move right" overlay would need a second,
/// on-device object detector running live against the camera feed -- a
/// separate model, separate training data, and a separate deployment target
/// from the cloud-hosted detect/classify pipeline this app already has. This
/// check needs none of that: it reuses the same detection response the app
/// already fetches for every capture, and reasons about it after the fact.
///
/// ## What it actually measures
///
/// Distance shows up directly in box size: a shelf photographed from further
/// away puts smaller boxes in the same frame. Measured against this
/// project's own labelled training data, real captures had a median box of
/// ~0.35% of the image area (p25 0.16%, p75 0.74%, p90 1.9%). A capture whose
/// *average* box sits well below that isn't proof of anything on its own --
/// but it's a real, free signal that costs nothing to check.
///
/// This is a starting threshold, not a proven cutoff -- tune it once real
/// field captures accumulate.
class CaptureQualityCheck {
  const CaptureQualityCheck._();

  /// Average box-area fraction below which a capture is flagged as likely
  /// taken from too far away.
  ///
  /// Set below this project's own measured p25 (0.16%), so it should flag
  /// genuinely small captures without tripping on ordinary ones.
  static const double smallBoxAreaThreshold = 0.0015;

  /// Detections below this count aren't enough to average box size
  /// meaningfully -- a single small product on an otherwise-empty shelf can
  /// have nothing to do with distance.
  static const int minDetectionsToJudge = 3;

  /// Whether [result] looks like it was captured from too far to trust.
  ///
  /// Declines to judge (`false`) rather than guessing when there isn't
  /// enough evidence: no detections, too few of them, or unknown image
  /// dimensions.
  static bool looksTooFar(DetectionResult result) {
    if (result.detections.length < minDetectionsToJudge) return false;

    final imageArea = result.imageWidth * result.imageHeight;
    if (imageArea <= 0) return false;

    var totalRatio = 0.0;
    for (final detection in result.detections) {
      totalRatio += detection.box.area / imageArea;
    }
    final averageRatio = totalRatio / result.detections.length;

    return averageRatio < smallBoxAreaThreshold;
  }
}
