import 'dart:math' as math;

import 'bounding_box.dart';
import 'detection.dart';
import 'detection_result.dart';

/// Where one entry in a draft came from.
///
/// Mirrors the `detection_origin` enum in Postgres.
enum DetectionOrigin {
  /// The model predicted this box.
  model,

  /// A person added it because the model missed a facing that was on the shelf.
  manual;

  String get dbValue => name;
}

/// One detection as it stands after any corrections.
class DraftDetection {
  final Detection detection;
  final DetectionOrigin origin;

  /// True when a person rejected this as a false positive.
  ///
  /// Rejected entries are kept rather than dropped. A model prediction that was
  /// wrong is worth as much as one that was right -- it is a training label
  /// either way, and it is the only evidence of what was changed.
  final bool removed;

  /// The class the model originally said, when a person has since changed it.
  final String? originalClass;

  const DraftDetection({
    required this.detection,
    this.origin = DetectionOrigin.model,
    this.removed = false,
    this.originalClass,
  });

  /// Whether this entry counts towards the submitted numbers.
  bool get counts => !removed;

  bool get wasReclassified => originalClass != null;

  DraftDetection copyWith({
    Detection? detection,
    bool? removed,
    String? originalClass,
  }) => DraftDetection(
    detection: detection ?? this.detection,
    origin: origin,
    removed: removed ?? this.removed,
    originalClass: originalClass ?? this.originalClass,
  );
}

/// A capture's detections, plus whatever the rep changed before submitting.
///
/// This exists because the model is not always right and the person holding the
/// phone is standing in front of the shelf. They can see a bottle it missed and
/// a reflection it counted twice, and a number they know to be wrong is a
/// number they stop trusting.
///
/// Corrections are additive, never destructive: rejecting a box marks it
/// [DraftDetection.removed] and adding one appends a
/// [DetectionOrigin.manual] entry. The raw prediction is always recoverable,
/// which is what keeps an editable number from being a gameable one.
class CaptureDraft {
  final List<DraftDetection> entries;
  final double imageWidth;
  final double imageHeight;

  const CaptureDraft({
    required this.entries,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// Starts a draft from what the model returned, with nothing yet corrected.
  factory CaptureDraft.fromResult(DetectionResult result) => CaptureDraft(
    entries: [
      for (final detection in result.detections)
        DraftDetection(detection: detection),
    ],
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
  );

  /// The detections as corrected, for display and for Share of Shelf.
  DetectionResult get corrected => DetectionResult(
    detections: [
      for (final entry in entries)
        if (entry.counts) entry.detection,
    ],
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );

  int get keptCount => entries.where((e) => e.counts).length;
  int get removedCount => entries.where((e) => e.removed).length;
  int get addedCount =>
      entries.where((e) => e.origin == DetectionOrigin.manual).length;

  /// Whether anything was changed from what the model said.
  bool get isEdited => entries.any(
    (e) => e.removed || e.origin == DetectionOrigin.manual || e.wasReclassified,
  );

  /// Kept facings per class, largest first, for the editor's per-class rows.
  List<({String className, int count})> get countsByClass {
    final counts = <String, int>{};
    for (final entry in entries) {
      if (entry.counts) {
        counts.update(
          entry.detection.className,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
    }
    return counts.entries
        .map((e) => (className: e.key, count: e.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.className.compareTo(b.className);
      });
  }

  /// Every class the draft knows about, including ones whose facings have all
  /// been removed -- otherwise rejecting the last one makes the row vanish and
  /// there is no way to put it back.
  List<String> get knownClasses {
    final seen = <String>{for (final e in entries) e.detection.className};
    return seen.toList()..sort();
  }

  CaptureDraft _withEntries(List<DraftDetection> next) => CaptureDraft(
    entries: next,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );

  /// Rejects or restores the entry at [index].
  CaptureDraft toggleRemoved(int index) {
    if (index < 0 || index >= entries.length) return this;
    final next = [...entries];
    next[index] = next[index].copyWith(removed: !next[index].removed);
    return _withEntries(next);
  }

  /// Reassigns one entry to a different product.
  ///
  /// The model's original answer is preserved on first change only, so
  /// correcting a correction still reports what the model actually said.
  CaptureDraft reclassify(int index, String className) {
    if (index < 0 || index >= entries.length) return this;
    final entry = entries[index];
    if (entry.detection.className == className) return this;

    final next = [...entries];
    next[index] = entry.copyWith(
      detection: Detection(
        className: className,
        confidence: entry.detection.confidence,
        box: entry.detection.box,
        classId: entry.detection.classId,
        trackerId: entry.detection.trackerId,
        packaging: entry.detection.packaging,
      ),
      originalClass: entry.originalClass ?? entry.detection.className,
    );
    return _withEntries(next);
  }

  /// Adds a facing the model missed.
  ///
  /// The box is synthetic: there is no way to know where on the shelf the
  /// missed item was, and asking someone to draw one at the fridge door is not
  /// a realistic thing to ask. It is sized to the median facing of the same
  /// class so Share of Shelf -- which is area-based -- moves by roughly what
  /// one more facing is worth, rather than by nothing at all. `origin` records
  /// that the geometry was inferred, so nothing downstream mistakes it for a
  /// measurement.
  CaptureDraft addManual(String className) {
    final area = _medianAreaFor(className);
    final side = area > 0
        ? math.sqrt(area)
        : (imageWidth > 0 ? imageWidth * 0.08 : 40.0);

    return _withEntries([
      ...entries,
      DraftDetection(
        origin: DetectionOrigin.manual,
        detection: Detection(
          className: className,
          // A person asserting a facing is not a probability, and storing 1.0
          // would let a manual entry outrank every real prediction in any
          // confidence-weighted view.
          confidence: 0,
          box: BoundingBox(
            centerX: imageWidth / 2,
            centerY: imageHeight / 2,
            width: side,
            height: side,
          ),
        ),
      ),
    ]);
  }

  /// Removes the least confident kept facing of [className].
  ///
  /// Least confident first because that is the one most likely to be the
  /// mistake, which makes the minus button do the useful thing by default.
  CaptureDraft removeOneOf(String className) {
    var target = -1;
    var lowest = double.infinity;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (!entry.counts || entry.detection.className != className) continue;
      if (entry.detection.confidence <= lowest) {
        lowest = entry.detection.confidence;
        target = i;
      }
    }
    return target < 0 ? this : toggleRemoved(target);
  }

  /// Median box area among kept facings of [className], falling back to all
  /// kept facings when that class has none left.
  double _medianAreaFor(String className) {
    List<double> areasWhere(bool Function(DraftDetection) test) => [
      for (final entry in entries)
        if (entry.counts && test(entry)) entry.detection.box.area,
    ]..sort();

    final sameClass = areasWhere((e) => e.detection.className == className);
    final areas = sameClass.isNotEmpty ? sameClass : areasWhere((_) => true);
    if (areas.isEmpty) return 0;
    return areas[areas.length ~/ 2];
  }
}
