import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/capture_draft.dart';
import 'detection_overlay.dart' show DetectionPalette;

/// The captured photo with every entry drawn on it, tappable.
///
/// Tapping a box is the fastest way to reject a false positive: the rep is
/// looking at the shelf and at the photo, and pointing at the wrong box is more
/// direct than finding the right row in a list.
///
/// Rejected boxes stay on screen, faint, rather than disappearing. A box that
/// vanishes on a mis-tap leaves nothing to tap again, and the whole point of
/// this screen is that corrections are reversible.
class EditableDetectionOverlay extends StatelessWidget {
  final Uint8List imageBytes;
  final CaptureDraft draft;

  /// Index into [CaptureDraft.entries] of the tapped entry.
  final ValueChanged<int> onToggle;

  const EditableDetectionOverlay({
    super.key,
    required this.imageBytes,
    required this.draft,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final index = _hitTest(details.localPosition, size);
            if (index != null) onToggle(index);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(imageBytes, fit: BoxFit.contain),
              CustomPaint(painter: _EditablePainter(draft: draft)),
            ],
          ),
        );
      },
    );
  }

  /// The entry under [point], preferring the smallest box that contains it.
  ///
  /// Smallest wins because facings overlap and nest: with a larger box on top,
  /// the tightly-drawn item you are actually pointing at would be unreachable.
  int? _hitTest(Offset point, Size size) {
    int? best;
    var bestArea = double.infinity;

    for (var i = 0; i < draft.entries.length; i++) {
      final rect = draft.entries[i].detection.box.toDisplayRect(
        imageWidth: draft.imageWidth,
        imageHeight: draft.imageHeight,
        displayWidth: size.width,
        displayHeight: size.height,
      );
      // Small boxes are hard to hit precisely on a phone, so grow the target
      // without growing what is drawn.
      if (!rect.inflate(6).contains(point)) continue;

      final area = rect.width * rect.height;
      if (area < bestArea) {
        bestArea = area;
        best = i;
      }
    }
    return best;
  }
}

class _EditablePainter extends CustomPainter {
  final CaptureDraft draft;

  const _EditablePainter({required this.draft});

  @override
  void paint(Canvas canvas, Size size) {
    if (draft.imageWidth <= 0 || draft.imageHeight <= 0) return;

    for (final entry in draft.entries) {
      final rect = entry.detection.box.toDisplayRect(
        imageWidth: draft.imageWidth,
        imageHeight: draft.imageHeight,
        displayWidth: size.width,
        displayHeight: size.height,
      );
      if (rect.isEmpty) continue;

      final base = DetectionPalette.forClass(entry.detection.className);
      final isManual = entry.origin == DetectionOrigin.manual;

      if (entry.removed) {
        // Faint outline plus a cross: unmistakably "not counted" at a glance,
        // and still large enough to tap again.
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          paint,
        );
        canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
        canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
        continue;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isManual ? 3 : 2.5
          ..color = base,
      );

      // A manually added facing has no real geometry -- the box is inferred
      // from the median facing of its class. Filling it says "this is an
      // assertion, not a measurement" without needing a legend.
      if (isManual) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = base.withValues(alpha: 0.28),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditablePainter old) => old.draft != draft;
}
