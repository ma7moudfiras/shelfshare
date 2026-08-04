import 'bounding_box.dart';

/// A single detected object on the shelf.
///
/// This is a UI-facing type: it deliberately carries only the fields the app
/// renders and reasons about. Anything heavy in the raw inference payload --
/// segmentation polygons in particular -- is dropped at parse time and never
/// reaches this class.
class Detection {
  /// Human-readable class label, e.g. `coca_cola`.
  final String className;

  /// Model confidence in the range 0.0 - 1.0.
  final double confidence;

  /// Where the object sits in the source image.
  final BoundingBox box;

  /// Numeric class id, when the model reports one. Not required for rendering.
  final int? classId;

  /// Tracker id, when the workflow includes a tracking block.
  final int? trackerId;

  const Detection({
    required this.className,
    required this.confidence,
    required this.box,
    this.classId,
    this.trackerId,
  });

  /// A copy carrying [className] instead, with the box and scores untouched.
  ///
  /// Used when a post-processing rule overrules the model's label -- the
  /// geometry it measured is still the model's, so only the name changes.
  Detection withClassName(String className) => Detection(
    className: className,
    confidence: confidence,
    box: box,
    classId: classId,
    trackerId: trackerId,
  );

  /// Confidence rendered for display, e.g. `87%`.
  String get confidenceLabel => '${(confidence * 100).round()}%';

  /// Label as drawn on the overlay, e.g. `coca_cola 87%`.
  String get displayLabel => '$className $confidenceLabel';

  @override
  String toString() => 'Detection($className, $confidenceLabel, $box)';
}
