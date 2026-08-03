import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/capture_draft.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/models/detection_result.dart';

Detection detection(
  String className, {
  double confidence = 0.9,
  double size = 40,
  double x = 100,
  double y = 100,
}) => Detection(
  className: className,
  confidence: confidence,
  box: BoundingBox(centerX: x, centerY: y, width: size, height: size),
);

CaptureDraft draftOf(List<Detection> detections) => CaptureDraft.fromResult(
  DetectionResult(detections: detections, imageWidth: 1000, imageHeight: 1000),
);

void main() {
  group('starting a draft', () {
    test('counts everything the model found and reports no edits', () {
      final draft = draftOf([detection('cola'), detection('pepsi')]);

      expect(draft.keptCount, 2);
      expect(draft.removedCount, 0);
      expect(draft.addedCount, 0);
      expect(draft.isEdited, isFalse);
    });
  });

  group('rejecting a facing', () {
    test('drops it from the count without discarding the prediction', () {
      final draft = draftOf([detection('cola'), detection('pepsi')]);
      final edited = draft.toggleRemoved(0);

      expect(edited.keptCount, 1);
      expect(edited.corrected.count, 1);
      expect(edited.isEdited, isTrue);

      // The raw prediction is what makes a corrected number defensible and a
      // rejected box a usable training label. It must survive.
      expect(edited.entries, hasLength(2));
      expect(edited.entries[0].removed, isTrue);
      expect(edited.entries[0].detection.className, 'cola');
    });

    test('is reversible', () {
      final draft = draftOf([detection('cola')]);
      expect(draft.toggleRemoved(0).toggleRemoved(0).keptCount, 1);
    });

    test('an out-of-range index changes nothing', () {
      final draft = draftOf([detection('cola')]);
      expect(draft.toggleRemoved(9).keptCount, 1);
      expect(draft.toggleRemoved(-1).keptCount, 1);
    });

    // The minus button should undo the model's worst guess first, which is the
    // one most likely to be the mistake being corrected.
    test('minus takes the least confident facing of that class', () {
      final draft = draftOf([
        detection('cola', confidence: 0.95),
        detection('cola', confidence: 0.42),
        detection('cola', confidence: 0.80),
      ]);

      final edited = draft.removeOneOf('cola');
      final removed = edited.entries.where((e) => e.removed).single;

      expect(removed.detection.confidence, 0.42);
      expect(edited.keptCount, 2);
    });

    test('minus on a class with nothing left is a no-op', () {
      final draft = draftOf([detection('cola')]);
      expect(draft.removeOneOf('pepsi').keptCount, 1);
    });
  });

  group('adding a missed facing', () {
    test('is marked manual and carries no confidence', () {
      final draft = draftOf([detection('cola')]).addManual('pepsi');
      final added = draft.entries.last;

      expect(added.origin, DetectionOrigin.manual);
      expect(draft.addedCount, 1);
      expect(draft.keptCount, 2);
      // A person asserting a facing is not a probability. Storing 1.0 would let
      // a hand-added entry outrank every real prediction in a confidence view.
      expect(added.detection.confidence, 0);
    });

    // Share of Shelf is area-based, so a zero-area entry would raise the count
    // while leaving the share untouched -- the number the customer actually
    // reads would ignore the correction entirely.
    test('gets a real area so Share of Shelf actually moves', () {
      final before = draftOf([
        detection('cola', size: 50),
        detection('cola', size: 50),
      ]);
      final after = before.addManual('pepsi');

      expect(after.entries.last.detection.box.area, greaterThan(0));

      final pepsi = after.corrected.shareOfShelf.shares.singleWhere(
        (s) => s.className == 'pepsi',
      );
      expect(pepsi.fraction, greaterThan(0));
    });

    test('is sized like the other facings of the same product', () {
      final draft = draftOf([
        detection('cola', size: 20),
        detection('pepsi', size: 60),
        detection('pepsi', size: 60),
      ]).addManual('pepsi');

      // Median pepsi facing is 60x60, so the inferred box matches it rather
      // than the much smaller cola.
      expect(draft.entries.last.detection.box.area, closeTo(3600, 1));
    });

    test('falls back to the overall median for an unseen product', () {
      final draft = draftOf([
        detection('cola', size: 30),
      ]).addManual('newcomer');

      expect(draft.entries.last.detection.box.area, closeTo(900, 1));
    });

    test('an empty photo still produces a usable box', () {
      final draft = draftOf(const []).addManual('cola');
      expect(draft.entries.single.detection.box.area, greaterThan(0));
    });
  });

  group('reclassifying', () {
    test('changes the class and remembers what the model said', () {
      final draft = draftOf([detection('cola')]).reclassify(0, 'pepsi');
      final entry = draft.entries.single;

      expect(entry.detection.className, 'pepsi');
      expect(entry.originalClass, 'cola');
      expect(entry.wasReclassified, isTrue);
      expect(draft.isEdited, isTrue);
    });

    // Correcting a correction must still report the model's original answer,
    // not the intermediate human one.
    test('keeps the model original through a second change', () {
      final draft = draftOf([
        detection('cola'),
      ]).reclassify(0, 'pepsi').reclassify(0, 'fanta');

      expect(draft.entries.single.detection.className, 'fanta');
      expect(draft.entries.single.originalClass, 'cola');
    });

    test('reassigning to the same class is a no-op', () {
      final draft = draftOf([detection('cola')]).reclassify(0, 'cola');
      expect(draft.entries.single.wasReclassified, isFalse);
      expect(draft.isEdited, isFalse);
    });
  });

  group('per-class rows', () {
    test('count only what will be submitted, largest first', () {
      final draft = draftOf([
        detection('cola'),
        detection('cola'),
        detection('pepsi'),
      ]).removeOneOf('cola');

      expect(draft.countsByClass, [
        (className: 'cola', count: 1),
        (className: 'pepsi', count: 1),
      ]);
    });

    // Rejecting the last facing of a product must not make its row disappear,
    // or there is no way to put it back.
    test('a fully rejected product is still a known class', () {
      final draft = draftOf([detection('cola')]).removeOneOf('cola');

      expect(draft.countsByClass, isEmpty);
      expect(draft.knownClasses, ['cola']);
    });
  });
}
