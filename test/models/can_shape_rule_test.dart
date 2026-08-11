import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/can_shape_rule.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/models/detection_result.dart';

Detection can(
  String className, {
  required double width,
  required double height,
  double centerX = 700,
  double centerY = 400,
  double confidence = 0.98,
}) => Detection(
  className: className,
  confidence: confidence,
  box: BoundingBox(
    centerX: centerX,
    centerY: centerY,
    width: width,
    height: height,
  ),
);

DetectionResult resultOf(
  List<Detection> detections, {
  double imageWidth = 1408,
  double imageHeight = 768,
}) => DetectionResult(
  detections: detections,
  imageWidth: imageWidth,
  imageHeight: imageHeight,
);

void main() {
  const rule = CanShapeRule();

  group('shapeClassOf', () {
    test('a tall box is a sleek can', () {
      expect(
        rule.shapeClassOf(can('coca-330-fat', width: 98, height: 253)),
        'coca-330-slim',
      );
    });

    test('a squat box is a standard can', () {
      expect(
        rule.shapeClassOf(can('coca-330-slim', width: 137, height: 235)),
        'coca-330-fat',
      );
    });

    test('classes outside the 330 ml pair are none of its business', () {
      expect(rule.shapeClassOf(can('pepsi', width: 98, height: 253)), isNull);
      expect(rule.shapeClassOf(can('unmatched', width: 98, height: 253)),
          isNull);
    });

    test('a degenerate box is not judged rather than dividing by zero', () {
      expect(rule.shapeClassOf(can('coca-330-fat', width: 0, height: 253)),
          isNull);
    });
  });

  // The image that exposed the problem: one fridge shot holding both formats,
  // sleek on the lower shelf and standard on the upper. The visual-search
  // classifier called all ten `coca-330-fat`; the boxes disagree unanimously.
  group('the shelf photo the classifier got wrong', () {
    // Straight from the workflow response: width x height, in image pixels.
    const sleekBoxes = [
      [112.0, 257.0, 316.0, 536.5],
      [109.0, 254.0, 450.5, 534.0],
      [98.0, 253.0, 580.0, 531.5],
      [104.0, 255.0, 897.0, 529.5],
      [107.0, 253.0, 1019.5, 525.5],
    ];
    const standardBoxes = [
      [137.0, 235.0, 305.5, 249.5],
      [128.0, 232.0, 444.0, 249.0],
      [125.0, 228.0, 773.5, 246.0],
      [126.0, 227.0, 903.0, 245.5],
      [124.0, 225.0, 1029.0, 242.5],
    ];

    Detection fromRow(List<double> row) => can(
      // What the classifier said about every single one of them.
      'coca-330-fat',
      width: row[0],
      height: row[1],
      centerX: row[2],
      centerY: row[3],
    );

    test('all ten are labelled by format', () {
      final refined = rule.applyTo(
        resultOf([
          ...sleekBoxes.map(fromRow),
          ...standardBoxes.map(fromRow),
        ]),
      );

      final labels = refined.detections.map((d) => d.className).toList();
      expect(labels.sublist(0, 5), everyElement('coca-330-slim'));
      expect(labels.sublist(5), everyElement('coca-330-fat'));
    });

    test('the two clusters sit clear of the threshold', () {
      double ratio(List<double> row) => row[1] / row[0];

      expect(sleekBoxes.map(ratio).reduce((a, b) => a < b ? a : b),
          greaterThan(2.2));
      expect(standardBoxes.map(ratio).reduce((a, b) => a > b ? a : b),
          lessThan(1.9));
    });

    test('boxes and confidences survive re-labelling untouched', () {
      final original = fromRow(sleekBoxes.first);
      final refined = rule.applyTo(resultOf([original]));
      final detection = refined.detections.single;

      expect(detection.className, 'coca-330-slim');
      expect(detection.confidence, original.confidence);
      expect(detection.box.width, original.box.width);
      expect(detection.box.height, original.box.height);
      expect(detection.box.centerX, original.box.centerX);
    });
  });

  group('applyTo', () {
    test('Share of Shelf reflects the corrected labels', () {
      final refined = rule.applyTo(
        resultOf([
          can('coca-330-fat', width: 100, height: 250),
          can('coca-330-fat', width: 130, height: 230),
        ]),
      );

      expect(refined.shareOfShelf.classCount, 2);
    });

    test('a result nothing applies to is returned as-is', () {
      final untouched = resultOf([can('pepsi', width: 100, height: 250)]);

      expect(identical(rule.applyTo(untouched), untouched), isTrue);
    });

    test('an empty result is returned as-is', () {
      final empty = resultOf(const []);

      expect(identical(rule.applyTo(empty), empty), isTrue);
    });

    // A can running off the edge of the photo is measured short, so its
    // proportions say nothing -- the classifier's answer stands.
    test('a can clipped by the frame keeps the label it came with', () {
      final refined = rule.applyTo(
        resultOf([
          // Tall enough to read as sleek, but its top is cut off at y = 0.
          can('coca-330-fat', width: 100, height: 250, centerX: 700,
              centerY: 124),
        ]),
      );

      expect(refined.detections.single.className, 'coca-330-fat');
    });

    test('unknown image dimensions do not disable the rule', () {
      final refined = rule.applyTo(
        resultOf([
          can('coca-330-fat', width: 100, height: 250),
        ], imageWidth: 0, imageHeight: 0),
      );

      expect(refined.detections.single.className, 'coca-330-slim');
    });
  });

  group('threshold', () {
    test('is configurable', () {
      const strict = CanShapeRule(slimAspectRatio: 3);

      expect(
        strict.shapeClassOf(can('coca-330-fat', width: 98, height: 253)),
        'coca-330-fat',
        reason: 'h/w of 2.58 is below a threshold of 3',
      );
    });

    test('is inclusive at the boundary', () {
      expect(
        rule.shapeClassOf(can('coca-330-fat', width: 100, height: 205)),
        'coca-330-slim',
      );
      expect(
        rule.shapeClassOf(can('coca-330-slim', width: 100, height: 204)),
        'coca-330-fat',
      );
    });

    test('class names are configurable', () {
      const renamed = CanShapeRule(slimClass: 'sleek', fatClass: 'standard');

      expect(
        renamed.shapeClassOf(can('standard', width: 98, height: 253)),
        'sleek',
      );
      expect(renamed.shapeClassOf(can('coca-330-fat', width: 98, height: 253)),
          isNull);
    });
  });
}
