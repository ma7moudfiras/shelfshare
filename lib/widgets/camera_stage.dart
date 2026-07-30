import 'package:flutter/material.dart';

/// Composes the live preview with its framing overlay.
///
/// Extracted from the capture screen for one reason: the rule it enforces is
/// subtle, it has been got wrong twice, and it cannot be tested in place --
/// building a real [CameraPreview] needs a real camera, which no widget test
/// has. Here the preview is just a [Widget], so the invariant is checkable.
///
/// The rule: **this subtree must be structurally identical for every framing
/// ratio.** Both of the following break the preview on web, permanently, with
/// no recovery even after returning to Full:
///
///  * Wrapping the preview differently per ratio (AspectRatio, ClipRRect, ...)
///    re-parents the platform view in the widget tree.
///  * Adding or removing a layer *over* the preview changes how many canvases
///    the web engine has to composite around the platform view, so it rebuilds
///    the DOM slot the `<video>` lives in and the element is orphaned.
///
/// So the preview keeps one fixed wrapper, and the mask is always mounted --
/// for Full it frames the whole screen and dims nothing.
class CameraStage extends StatelessWidget {
  /// The live viewfinder. Sized to fill the stage.
  final Widget preview;

  /// Width divided by height of the region that will survive the crop, or null
  /// for Full.
  final double? ratio;

  const CameraStage({super.key, required this.preview, required this.ratio});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          key: const ValueKey('camera-preview'),
          child: SizedBox.expand(child: preview),
        ),
        Positioned.fill(
          child: FramingMask(
            key: const ValueKey('framing-mask'),
            ratio: ratio,
          ),
        ),
      ],
    );
  }
}

/// Dims everything outside the selected framing.
///
/// An overlay rather than a resize, and always mounted -- see [CameraStage].
class FramingMask extends StatelessWidget {
  /// Null for Full, which keeps the whole frame.
  final double? ratio;

  const FramingMask({super.key, required this.ratio});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: FramingMaskPainter(
          ratio: ratio,
          // Matches the crop the captured image actually receives.
          scrim: Colors.black.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

@visibleForTesting
class FramingMaskPainter extends CustomPainter {
  /// Null means Full: the frame is the whole screen and nothing is dimmed.
  final double? ratio;
  final Color scrim;

  const FramingMaskPainter({required this.ratio, required this.scrim});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final frame = frameRect(size);
    final paint = Paint()..color = scrim;

    // Four solid bands rather than punching the frame out of a full-bleed
    // scrim: plain rects need no path arithmetic, so there is no way to hand
    // the compositor degenerate geometry.
    if (frame.top > 0) {
      canvas.drawRect(Rect.fromLTRB(0, 0, size.width, frame.top), paint);
    }
    if (frame.bottom < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(0, frame.bottom, size.width, size.height),
        paint,
      );
    }
    if (frame.left > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, frame.top, frame.left, frame.bottom),
        paint,
      );
    }
    if (frame.right < size.width) {
      canvas.drawRect(
        Rect.fromLTRB(frame.right, frame.top, size.width, frame.bottom),
        paint,
      );
    }

    // Drawn in every state, Full included, so this layer is never empty and the
    // engine's compositing decisions do not change with the ratio. Inset by
    // half the stroke so a full-screen frame is not clipped by the edge.
    canvas.drawRect(
      frame.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  /// Largest rect of [ratio] that fits inside [size], centred.
  ///
  /// Falls back to the screen's own ratio, which yields the full frame.
  @visibleForTesting
  Rect frameRect(Size size) {
    final target = ratio ?? size.width / size.height;
    if (!target.isFinite || target <= 0) return Offset.zero & size;

    var width = size.width;
    var height = width / target;
    if (height > size.height) {
      height = size.height;
      width = height * target;
    }
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  @override
  bool shouldRepaint(covariant FramingMaskPainter old) =>
      old.ratio != ratio || old.scrim != scrim;
}
