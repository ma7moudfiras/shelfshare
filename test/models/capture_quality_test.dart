import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/capture_quality.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/models/detection_result.dart';

Detection detectionOfArea(double width, double height) => Detection(
  className: 'coca-cola',
  confidence: 0.9,
  box: BoundingBox(centerX: 100, centerY: 100, width: width, height: height),
);

DetectionResult resultOf(
  List<Detection> detections, {
  double imageWidth = 1000,
  double imageHeight = 1000,
}) => DetectionResult(
  detections: detections,
  imageWidth: imageWidth,
  imageHeight: imageHeight,
);

void main() {
  group('CaptureQualityCheck.looksTooFar', () {
    test('flags a capture whose boxes are all tiny relative to the image', () {
      // Image is 1000x1000 = 1,000,000 sq px. Each box is 20x20 = 400 sq px,
      // a ratio of 0.04% -- well under the 0.15% threshold.
      final result = resultOf([
        detectionOfArea(20, 20),
        detectionOfArea(20, 20),
        detectionOfArea(20, 20),
      ]);

      expect(CaptureQualityCheck.looksTooFar(result), isTrue);
    });

    test('does not flag a capture with realistically sized boxes', () {
      // 60x150 = 9,000 sq px on a 1,000,000 sq px image = 0.9%, above
      // threshold and close to this project's own measured p75 (0.74%).
      final result = resultOf([
        detectionOfArea(60, 150),
        detectionOfArea(60, 150),
        detectionOfArea(60, 150),
      ]);

      expect(CaptureQualityCheck.looksTooFar(result), isFalse);
    });

    test('declines to judge below minDetectionsToJudge', () {
      // Only 2 detections, both tiny -- still declines, since a couple of
      // small boxes isn't enough evidence on its own.
      final result = resultOf([
        detectionOfArea(20, 20),
        detectionOfArea(20, 20),
      ]);

      expect(CaptureQualityCheck.looksTooFar(result), isFalse);
    });

    test('declines to judge an empty result', () {
      expect(CaptureQualityCheck.looksTooFar(resultOf(const [])), isFalse);
    });

    test('declines to judge when image dimensions are unknown', () {
      final result = resultOf([
        detectionOfArea(20, 20),
        detectionOfArea(20, 20),
        detectionOfArea(20, 20),
      ], imageWidth: 0, imageHeight: 0);

      expect(CaptureQualityCheck.looksTooFar(result), isFalse);
    });

    test('a single large box drags the average above threshold', () {
      // Mostly-tiny boxes plus one large one: the average should land above
      // threshold, since this is an average-based check, not a min/max one.
      final result = resultOf([
        detectionOfArea(20, 20),
        detectionOfArea(20, 20),
        detectionOfArea(500, 500),
      ]);

      expect(CaptureQualityCheck.looksTooFar(result), isFalse);
    });

    test('is inclusive at the boundary', () {
      // Ratio exactly at threshold (0.15%) should not be flagged -- the
      // check is a strict less-than.
      const imageArea = 1000.0 * 1000.0;
      final edge = sqrt(imageArea * CaptureQualityCheck.smallBoxAreaThreshold);

      final result = resultOf([
        detectionOfArea(edge, edge),
        detectionOfArea(edge, edge),
        detectionOfArea(edge, edge),
      ]);

      expect(CaptureQualityCheck.looksTooFar(result), isFalse);
    });
  });
}
