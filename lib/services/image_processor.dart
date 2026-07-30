import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/capture_aspect_ratio.dart';

/// Prepares captured photos for upload: crop to the chosen framing, then
/// compress to fit inside the request budget.
///
/// ## Why compression is safe here
///
/// The `aystro-project` dataset preprocesses to **704x704** ("Stretch to"), so
/// Roboflow throws away everything above that before the model ever sees it.
/// Sending a 12-megapixel photo does not buy a single pixel of extra accuracy;
/// it only makes the request slower, larger, and more likely to be rejected.
/// [maxEdge] is set comfortably above 704 so the resize stays a downsample
/// rather than a crop of detail the model would have used.
class ImageProcessor {
  const ImageProcessor();

  /// Longest edge kept after processing.
  ///
  /// Roughly 2x the model's 704px input, which leaves headroom for the
  /// "Stretch to" resize without carrying pixels nothing will read.
  static const int maxEdge = 1400;

  /// Starting JPEG quality. Visually indistinguishable at shelf distances.
  static const int startQuality = 88;

  /// Byte budget for the encoded JPEG.
  ///
  /// Vercel caps a serverless function's request body at ~4.5 MB, and base64
  /// inflates bytes by about a third. 1.5 MB of JPEG becomes roughly 2 MB of
  /// base64, which leaves comfortable room for the JSON envelope.
  static const int maxUploadBytes = 1500 * 1024;

  /// Quality steps tried before the image is downscaled further.
  static const List<int> _qualitySteps = [88, 78, 68, 58];

  /// Edge sizes tried if quality reduction alone is not enough.
  static const List<int> _edgeSteps = [1400, 1100, 900, 704];

  /// Crops [bytes] to [aspect] and compresses the result under the budget.
  ///
  /// Runs on a background isolate off the web, where isolates are unavailable
  /// and the work necessarily stays on the main thread.
  Future<Uint8List> prepareForUpload(
    Uint8List bytes,
    CaptureAspectRatio aspect,
  ) async {
    final request = _PrepareRequest(bytes, aspect.ratio);
    return kIsWeb ? _prepare(request) : compute(_prepare, request);
  }
}

@immutable
class _PrepareRequest {
  final Uint8List bytes;

  /// Target width/height, or null to keep the frame uncropped.
  final double? ratio;

  const _PrepareRequest(this.bytes, this.ratio);
}

/// Crops, downscales and JPEG-encodes until the result fits the byte budget.
///
/// Top-level so it can be handed to an isolate. Returns the original bytes on
/// failure -- a processing error must not cost the operator their shot; the
/// request will still be attempted and the server will report if it is too big.
Uint8List _prepare(_PrepareRequest request) {
  try {
    final decoded = img.decodeImage(request.bytes);
    if (decoded == null) return request.bytes;

    var working = decoded;

    // 1. Crop to the selected framing, if any.
    final ratio = request.ratio;
    if (ratio != null) {
      final sourceRatio = working.width / working.height;
      int cropWidth;
      int cropHeight;
      if (sourceRatio > ratio) {
        cropHeight = working.height;
        cropWidth = (working.height * ratio).round();
      } else {
        cropWidth = working.width;
        cropHeight = (working.width / ratio).round();
      }

      working = img.copyCrop(
        working,
        // Centre the crop: the subject is framed in the middle of the frame.
        x: ((working.width - cropWidth.clamp(1, working.width)) / 2).round(),
        y: ((working.height - cropHeight.clamp(1, working.height)) / 2).round(),
        width: cropWidth.clamp(1, working.width),
        height: cropHeight.clamp(1, working.height),
      );
    }

    // 2. Downscale, then trade quality, then trade resolution, until the
    //    encoded result fits. Quality is spent before resolution because
    //    JPEG artefacts cost the detector far less than lost pixels.
    Uint8List? best;
    for (final edge in ImageProcessor._edgeSteps) {
      final scaled = _resizeToEdge(working, edge);

      for (final quality in ImageProcessor._qualitySteps) {
        final encoded = img.encodeJpg(scaled, quality: quality);
        best = encoded;
        if (encoded.length <= ImageProcessor.maxUploadBytes) return encoded;
      }
    }

    // Every combination was still over budget; send the smallest produced.
    return best ?? request.bytes;
  } catch (_) {
    return request.bytes;
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
    interpolation: img.Interpolation.average,
  );
}
