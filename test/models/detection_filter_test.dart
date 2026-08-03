import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/models/detection_result.dart';
import 'package:shelf_monitor/models/model_option.dart';

Detection detection(String className, double size) => Detection(
  className: className,
  confidence: 0.9,
  box: BoundingBox(centerX: 50, centerY: 50, width: size, height: size),
);

DetectionResult resultOf(List<Detection> detections) =>
    DetectionResult(detections: detections, imageWidth: 720, imageHeight: 540);

void main() {
  group('filterByClasses', () {
    final result = resultOf([
      detection('coca-cola', 20), // 400
      detection('pepsi', 10), // 100
      detection('cappy', 10), // 100
    ]);

    test('an empty selection means all products', () {
      expect(result.filterByClasses({}).count, 3);
      expect(result.filterByClasses(null).count, 3);
    });

    test('keeps only the selected classes', () {
      final filtered = result.filterByClasses({'pepsi', 'cappy'});

      expect(filtered.count, 2);
      expect(filtered.classNames, containsAll(['pepsi', 'cappy']));
      expect(filtered.classNames, isNot(contains('coca-cola')));
    });

    // The point of the filter: comparing two brands should report their split
    // of each other, not their slice of everything on the shelf.
    test('Share of Shelf is recomputed across the selection only', () {
      expect(
        result.shareOfShelf.shares.first.percentage,
        closeTo(66.7, 0.1),
        reason: 'coca-cola is 400 of 600 unfiltered',
      );

      final filtered = result.filterByClasses({'pepsi', 'cappy'});
      expect(filtered.shareOfShelf.classCount, 2);
      for (final share in filtered.shareOfShelf.shares) {
        expect(share.percentage, closeTo(50, 0.001));
      }
      expect(filtered.shareOfShelf.summaryLine, 'cappy: 50% | pepsi: 50%');
    });

    test('selecting an absent class yields an empty result, not a crash', () {
      final filtered = result.filterByClasses({'not_stocked'});

      expect(filtered.isEmpty, isTrue);
      expect(filtered.shareOfShelf.summaryLine, 'No products detected');
    });

    test('preserves image dimensions so the overlay still projects', () {
      final filtered = result.filterByClasses({'pepsi'});

      expect(filtered.imageWidth, 720);
      expect(filtered.imageHeight, 540);
    });
  });

  group('ModelCatalog', () {
    test('parses the proxy response', () {
      final catalog = ModelCatalog.fromJson({
        'models': [
          {
            'modelId': 'aystro-project/11',
            'version': 11,
            'name': '2026-07-29 12:40pm',
            'images': 227,
            'map50': 100.0,
            'recall': 100.0,
          },
          {
            'modelId': 'aystro-project/9',
            'version': 9,
            'name': '2026-07-29 12:04am',
            'images': 209,
            'map50': 86.4,
            'recall': 88.0,
          },
        ],
        'classes': ['cappy', 'coca-cola', 'pepsi', 'xl_energy'],
      });

      expect(catalog.models, hasLength(2));
      expect(catalog.models.first.modelId, 'aystro-project/11');
      expect(catalog.models.first.label, 'Version 11');
      expect(catalog.models.first.subtitle, contains('227 images'));
      expect(catalog.classes, hasLength(4));
    });

    test('survives a malformed or empty payload', () {
      expect(ModelCatalog.fromJson({}).isEmpty, isTrue);
      expect(ModelCatalog.fromJson({'models': 'nonsense'}).models, isEmpty);
      expect(
        ModelCatalog.fromJson({
          'models': [
            {'version': 3},
          ],
        }).models,
        isEmpty,
        reason: 'entries without a modelId cannot be run',
      );
    });
  });
}
