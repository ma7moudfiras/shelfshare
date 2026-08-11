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
    test('a tall box is a slim can', () {
      expect(
        rule.shapeClassOf(can('coca-cola', width: 98, height: 253)),
        'coca-cola-slim',
      );
    });

    test('a squat box is a standard can', () {
      expect(
        rule.shapeClassOf(can('coca-cola', width: 137, height: 235)),
        'coca-cola-standard',
      );
    });

    test('brands outside dualFormatBrands are none of its business', () {
      expect(rule.shapeClassOf(can('pepsi', width: 98, height: 253)), isNull);
      expect(
        rule.shapeClassOf(can('unmatched', width: 98, height: 253)),
        isNull,
      );
    });

    test('a degenerate box is not judged rather than dividing by zero', () {
      expect(
        rule.shapeClassOf(can('coca-cola', width: 0, height: 253)),
        isNull,
      );
    });
  });

  // The image that exposed the problem: one fridge shot holding both formats,
  // slim on the lower shelf and standard on the upper. The brand classifier
  // called all ten plain `coca-cola`; the boxes disagree unanimously.
  group('the shelf photo the classifier got wrong', () {
    // Straight from the workflow response: width x height, in image pixels.
    const slimBoxes = [
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
      'coca-cola',
      width: row[0],
      height: row[1],
      centerX: row[2],
      centerY: row[3],
    );

    test('all ten are labelled by format', () {
      final refined = rule.applyTo(
        resultOf([...slimBoxes.map(fromRow), ...standardBoxes.map(fromRow)]),
      );

      final labels = refined.detections.map((d) => d.className).toList();
      expect(labels.sublist(0, 5), everyElement('coca-cola-slim'));
      expect(labels.sublist(5), everyElement('coca-cola-standard'));
    });

    test('the two clusters sit clear of the threshold', () {
      double ratio(List<double> row) => row[1] / row[0];

      expect(
        slimBoxes.map(ratio).reduce((a, b) => a < b ? a : b),
        greaterThan(2.2),
      );
      expect(
        standardBoxes.map(ratio).reduce((a, b) => a > b ? a : b),
        lessThan(1.9),
      );
    });

    test('boxes and confidences survive re-labelling untouched', () {
      final original = fromRow(slimBoxes.first);
      final refined = rule.applyTo(resultOf([original]));
      final detection = refined.detections.single;

      expect(detection.className, 'coca-cola-slim');
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
          can('coca-cola', width: 100, height: 250),
          can('coca-cola', width: 130, height: 230),
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
          // Tall enough to read as slim, but its top is cut off at y = 0.
          can('coca-cola', width: 100, height: 250, centerX: 700, centerY: 124),
        ]),
      );

      expect(refined.detections.single.className, 'coca-cola');
    });

    // The rule's proportions are calibrated on 330 ml cans; a 2-litre bottle
    // of the same brand is tall and narrow too, and can clear the slim
    // threshold just as easily -- exactly what produced a `coca-cola-slim`
    // label on a 2-litre plastic bottle standing among cans.
    test('a bottle standing among cans of the same brand keeps the '
        'classifier\'s label', () {
      final refined = rule.applyTo(
        resultOf([
          can('coca-cola', width: 98, height: 253, centerX: 300),
          can('coca-cola', width: 104, height: 255, centerX: 500),
          can('coca-cola', width: 137, height: 235, centerX: 700),
          // A 2-litre bottle: roughly 2.4x a can's height, and still well
          // past the slim aspect-ratio threshold on its own.
          can('coca-cola', width: 95, height: 610, centerX: 900),
        ]),
      );

      final labels = refined.detections.map((d) => d.className).toList();
      expect(labels[0], 'coca-cola-slim');
      expect(labels[1], 'coca-cola-slim');
      expect(labels[2], 'coca-cola-standard');
      expect(labels[3], 'coca-cola', reason: 'left as the classifier said it');
    });

    test('a lone detection with nothing to compare against still judges on '
        'aspect ratio alone', () {
      // No reference height is available -- this is the one documented
      // limitation of a purely relative signal.
      final refined = rule.applyTo(
        resultOf([can('coca-cola', width: 95, height: 610)]),
      );

      expect(refined.detections.single.className, 'coca-cola-slim');
    });

    test('unknown image dimensions do not disable the rule', () {
      final refined = rule.applyTo(
        resultOf(
          [can('coca-cola', width: 100, height: 250)],
          imageWidth: 0,
          imageHeight: 0,
        ),
      );

      expect(refined.detections.single.className, 'coca-cola-slim');
    });
  });

  group('threshold', () {
    test('is configurable', () {
      const strict = CanShapeRule(slimAspectRatio: 3);

      expect(
        strict.shapeClassOf(can('coca-cola', width: 98, height: 253)),
        'coca-cola-standard',
        reason: 'h/w of 2.58 is below a threshold of 3',
      );
    });

    test('is inclusive at the boundary', () {
      expect(
        rule.shapeClassOf(can('coca-cola', width: 100, height: 205)),
        'coca-cola-slim',
      );
      expect(
        rule.shapeClassOf(can('coca-cola', width: 100, height: 204)),
        'coca-cola-standard',
      );
    });
  });

  group('dualFormatBrands', () {
    test('is configurable per brand', () {
      const multiband = CanShapeRule(
        dualFormatBrands: {
          'xl_energy': ('xl_energy-slim', 'xl_energy-standard'),
        },
      );

      expect(
        multiband.shapeClassOf(can('xl_energy', width: 98, height: 253)),
        'xl_energy-slim',
      );
      // coca-cola is no longer declared on this instance, so it passes through.
      expect(
        multiband.shapeClassOf(can('coca-cola', width: 98, height: 253)),
        isNull,
      );
    });

    test('supports more than one brand at once', () {
      const both = CanShapeRule(
        dualFormatBrands: {
          'coca-cola': ('coca-cola-slim', 'coca-cola-standard'),
          'xl_energy': ('xl_energy-slim', 'xl_energy-standard'),
        },
      );

      final refined = both.applyTo(
        resultOf([
          can('coca-cola', width: 98, height: 253, centerX: 100),
          can('xl_energy', width: 98, height: 253, centerX: 300),
        ]),
      );

      final labels = refined.detections.map((d) => d.className).toList();
      expect(labels, ['coca-cola-slim', 'xl_energy-slim']);
    });
  });
}
