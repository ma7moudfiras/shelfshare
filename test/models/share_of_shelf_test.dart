import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/models/share_of_shelf.dart';

Detection detection(String className, double width, double height) {
  return Detection(
    className: className,
    confidence: 0.9,
    box: BoundingBox(centerX: 100, centerY: 100, width: width, height: height),
  );
}

void main() {
  group('ShareOfShelf', () {
    test('splits area between two classes', () {
      // 3 x (10x10) = 300 for cola, 1 x (10x10) = 100 for pepsi -> 75% / 25%.
      final share = ShareOfShelf.fromDetections([
        detection('coca_cola', 10, 10),
        detection('coca_cola', 10, 10),
        detection('coca_cola', 10, 10),
        detection('pepsi', 10, 10),
      ]);

      expect(share.totalArea, 400);
      expect(share.classCount, 2);
      expect(share.detectionCount, 4);
      expect(share.shares.first.className, 'coca_cola');
      expect(share.shares.first.percentage, closeTo(75, 0.001));
      expect(share.shares.last.percentage, closeTo(25, 0.001));
      expect(share.summaryLine, 'coca_cola: 75% | pepsi: 25%');
    });

    test('weights by box area, not detection count', () {
      // One big box outweighs three small ones.
      final share = ShareOfShelf.fromDetections([
        detection('big', 100, 100), // 10000
        detection('small', 10, 10), // 100
        detection('small', 10, 10), // 100
        detection('small', 10, 10), // 100
      ]);

      // 10000 / (10000 + 300) = 97.09%
      expect(share.shares.first.className, 'big');
      expect(share.shares.first.percentage, closeTo(97.09, 0.01));
    });

    test('orders shares largest first', () {
      final share = ShareOfShelf.fromDetections([
        detection('c', 10, 10),
        detection('a', 30, 30),
        detection('b', 20, 20),
      ]);

      expect(share.shares.map((s) => s.className), ['a', 'b', 'c']);
    });

    test('fractions always sum to 1', () {
      final share = ShareOfShelf.fromDetections([
        detection('a', 13, 17),
        detection('b', 29, 31),
        detection('c', 7, 11),
      ]);

      final total = share.shares.fold<double>(0, (sum, s) => sum + s.fraction);
      expect(total, closeTo(1.0, 1e-9));
    });

    test('degenerate boxes do not contribute or crash', () {
      final share = ShareOfShelf.fromDetections([
        detection('real', 10, 10),
        detection('zero', 0, 50),
        detection('negative', -5, 10),
      ]);

      expect(share.classCount, 1);
      expect(share.shares.single.className, 'real');
      expect(share.shares.single.percentage, closeTo(100, 0.001));
    });

    test('no detections gives an empty result', () {
      final share = ShareOfShelf.fromDetections([]);

      expect(share.isEmpty, isTrue);
      expect(share.totalArea, 0);
      expect(share.summaryLine, 'No products detected');
    });

    test('only degenerate boxes gives an empty result', () {
      final share = ShareOfShelf.fromDetections([detection('zero', 0, 0)]);

      expect(share.isEmpty, isTrue);
    });
  });

  group('BoundingBox', () {
    test('derives edges from centre and size', () {
      const box = BoundingBox(centerX: 100, centerY: 50, width: 40, height: 20);

      expect(box.left, 80);
      expect(box.top, 40);
      expect(box.right, 120);
      expect(box.bottom, 60);
      expect(box.area, 800);
    });

    test('projects onto a letterboxed display', () {
      const box = BoundingBox(
        centerX: 50,
        centerY: 50,
        width: 100,
        height: 100,
      );

      // 100x100 image inside a 200x100 view: scale 1.0, 50px letterbox each side.
      final rect = box.toDisplayRect(
        imageWidth: 100,
        imageHeight: 100,
        displayWidth: 200,
        displayHeight: 100,
      );

      expect(rect.left, 50);
      expect(rect.top, 0);
      expect(rect.width, 100);
      expect(rect.height, 100);
    });
  });
}
