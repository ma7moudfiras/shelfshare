import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Flags a captured photo as motion-blurred or out of focus, before upload.
///
/// ## Why this, not just trusting Roboflow
///
/// A blurred shelf photo doesn't fail loudly -- it just quietly produces
/// lower-confidence, more-missed detections, the same way a too-far shot
/// does (see `CaptureQualityCheck`). Catching it locally, before the photo
/// ever leaves the device, costs one cheap on-device pass instead of a
/// wasted round trip to Roboflow.
///
/// ## The technique
///
/// Variance of the Laplacian: a classical, model-free sharpness measure. A
/// sharp image has strong edges, which show up as large second-derivative
/// responses; a blurred image's edges are smoothed away, so the Laplacian
/// response stays small and uniform across the frame. Its variance is
/// therefore a cheap proxy for "how much real detail is in this photo" -- no
/// model, no training data, runs in milliseconds on a small thumbnail.
class BlurDetector {
  const BlurDetector._();

  /// Longest edge the sharpness check actually runs on.
  ///
  /// Blur is a property of the whole image, not fine detail, so a small
  /// thumbnail is enough -- this keeps the pass cheap regardless of the
  /// original capture's resolution.
  static const int analysisEdge = 300;

  /// Laplacian-variance threshold below which a photo is judged blurry.
  ///
  /// A starting point, not a calibrated cutoff -- classic values in the
  /// literature range roughly 100-500 depending on sensor and lighting.
  /// Tune once real field captures accumulate false positives/negatives.
  static const double blurThreshold = 120;

  /// Whether [bytes] looks blurry enough to warrant a retake.
  ///
  /// Declines to judge (`false`) on any decoding failure -- a blur check
  /// must never be the reason a capture is blocked.
  ///
  /// Runs on a background isolate off the web, where isolates are
  /// unavailable and the work necessarily stays on the main thread.
  static Future<bool> isBlurry(Uint8List bytes) {
    return kIsWeb ? Future.value(_isBlurry(bytes)) : compute(_isBlurry, bytes);
  }
}

/// Top-level so it can be handed to an isolate.
bool _isBlurry(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return false;

    final small = _resizeToEdge(decoded, BlurDetector.analysisEdge);
    final gray = img.grayscale(small);

    return _laplacianVariance(gray) < BlurDetector.blurThreshold;
  } catch (_) {
    return false;
  }
}

/// Scales [source] so its longest edge is at most [edge], preserving aspect.
img.Image _resizeToEdge(img.Image source, int edge) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= edge) return source;

  return img.copyResize(
    source,
    width: source.width >= source.height ? edge : null,
    height: source.height > source.width ? edge : null,
  );
}

/// Variance of a 3x3 Laplacian response ([[0,1,0],[1,-4,1],[0,1,0]]) across
/// every interior pixel of [gray].
double _laplacianVariance(img.Image gray) {
  final width = gray.width;
  final height = gray.height;
  if (width < 3 || height < 3) return 0;

  final responses = <double>[];
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final center = gray.getPixel(x, y).r;
      final up = gray.getPixel(x, y - 1).r;
      final down = gray.getPixel(x, y + 1).r;
      final left = gray.getPixel(x - 1, y).r;
      final right = gray.getPixel(x + 1, y).r;

      responses.add((up + down + left + right - 4 * center).toDouble());
    }
  }
  if (responses.isEmpty) return 0;

  final mean = responses.reduce((a, b) => a + b) / responses.length;
  final sumSquaredDiff = responses
      .map((r) => (r - mean) * (r - mean))
      .reduce((a, b) => a + b);
  return sumSquaredDiff / responses.length;
}
