import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/widgets/detection_overlay.dart';

void main() {
  DetectionPainter painterOf({double viewScale = 1}) => DetectionPainter(
    detections: const [
      Detection(
        className: 'coca-cola',
        confidence: 0.9,
        box: BoundingBox(centerX: 100, centerY: 100, width: 40, height: 90),
      ),
    ],
    imageWidth: 400,
    imageHeight: 300,
    viewScale: viewScale,
  );

  group('DetectionPainter.shouldRepaint', () {
    // The whole point of threading viewScale through is that the overlay
    // repaints with thinner strokes/smaller text as an ancestor
    // InteractiveViewer zooms in -- a painter that ignores a changed
    // viewScale here would silently freeze at whatever size it first drew,
    // which is exactly the bug this rebuild wiring exists to fix.
    test('is true when only viewScale changes', () {
      expect(
        painterOf(viewScale: 1).shouldRepaint(painterOf(viewScale: 3)),
        isTrue,
      );
    });

    test('is false when nothing changed', () {
      expect(
        painterOf(viewScale: 2).shouldRepaint(painterOf(viewScale: 2)),
        isFalse,
      );
    });
  });

  group('DetectionPainter defaults', () {
    test('viewScale defaults to 1 outside an InteractiveViewer', () {
      expect(painterOf().viewScale, 1);
    });
  });
}
