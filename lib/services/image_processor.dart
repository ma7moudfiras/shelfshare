import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/capture_aspect_ratio.dart';

/// Crops captured photos to the framing the operator selected.
///
/// The crop is applied before inference so what was framed is what gets
/// analysed. Anything else would report products the operator deliberately
/// excluded from the shot.
class ImageProcessor {
  const ImageProcessor();

  /// JPEG quality for re-encoded crops.
  ///
  /// 88 is visually indistinguishable from the source at shelf distances while
  /// keeping the base64 payload roughly a third of what a PNG would cost.
  static const int _jpegQuality = 88;

  /// Longest edge kept after cropping.
  ///
  /// Full-resolution phone captures are far larger than the model's 704px
  /// input, so sending them only inflates the request.
  static const int _maxEdge = 1600;

  /// Returns [bytes] cropped to [aspect], or unchanged when no crop applies.
  ///
  /// Decoding and re-encoding are pure Dart and cost real time on a large
  /// image, so this runs on a background isolate off the web, where isolates
  /// are unavailable and the work stays on the main thread.
  Future<Uint8List> cropToAspect(
    Uint8List bytes,
    CaptureAspectRatio aspect,
  ) async {
    if (!aspect.cropsFrame) return bytes;

    final request = _CropRequest(bytes, aspect.ratio!);

    // compute() falls back to running inline on web, which is what we want:
    // there is no isolate to hand this to there.
    return kIsWeb ? _crop(request) : compute(_crop, request);
  }
}

/// Arguments for the isolate entry point, which takes a single value.
@immutable
class _CropRequest {
  final Uint8List bytes;
  final double ratio;

  const _CropRequest(this.bytes, this.ratio);
}

/// Centre-crops to [ratio] and re-encodes as JPEG.
///
/// Top-level so it can be sent to an isolate. Returns the original bytes on any
/// failure -- a crop that cannot be produced must not cost the user their shot.
Uint8List _crop(_CropRequest request) {
  try {
    final decoded = img.decodeImage(request.bytes);
    if (decoded == null) return request.bytes;

    final sourceRatio = decoded.width / decoded.height;
    final target = request.ratio;

    int cropWidth;
    int cropHeight;
    if (sourceRatio > target) {
      // Source is wider than wanted: trim the sides.
      cropHeight = decoded.height;
      cropWidth = (decoded.height * target).round();
    } else {
      // Source is taller than wanted: trim top and bottom.
      cropWidth = decoded.width;
      cropHeight = (decoded.width / target).round();
    }

    cropWidth = cropWidth.clamp(1, decoded.width);
    cropHeight = cropHeight.clamp(1, decoded.height);

    var out = img.copyCrop(
      decoded,
      // Centre the crop: the subject is framed in the middle of the viewfinder.
      x: ((decoded.width - cropWidth) / 2).round(),
      y: ((decoded.height - cropHeight) / 2).round(),
      width: cropWidth,
      height: cropHeight,
    );

    final longest = out.width > out.height ? out.width : out.height;
    if (longest > ImageProcessor._maxEdge) {
      out = img.copyResize(
        out,
        width: out.width >= out.height ? ImageProcessor._maxEdge : null,
        height: out.height > out.width ? ImageProcessor._maxEdge : null,
        interpolation: img.Interpolation.average,
      );
    }

    return img.encodeJpg(out, quality: ImageProcessor._jpegQuality);
  } catch (_) {
    return request.bytes;
  }
}
