import 'dart:typed_data';

import 'detection.dart';
import 'share_of_shelf.dart';

/// The outcome of running one image through the detection pipeline.
///
/// This is the only detection type the UI layer touches. It knows nothing about
/// Roboflow, its response envelope, or its output naming -- translating that raw
/// shape into this one is entirely the service layer's job, which keeps the
/// widgets stable if the workflow is rewired.
class DetectionResult {
  /// Every object detected in the image.
  final List<Detection> detections;

  /// Width of the source image in pixels, used to project boxes onto the view.
  final double imageWidth;

  /// Height of the source image in pixels, used to project boxes onto the view.
  final double imageHeight;

  /// Pre-rendered annotated image returned by the workflow, if it produced one.
  ///
  /// Held in memory and rendered with `Image.memory` rather than written to
  /// disk. Never log this -- it is routinely hundreds of kilobytes.
  final Uint8List? annotatedImage;

  /// Which workflow output key the [detections] were read from. Useful when
  /// diagnosing a workflow whose output names have changed.
  final String? sourceOutputKey;

  /// Wall-clock time the inference call took.
  final Duration? inferenceTime;

  /// The model version that actually produced these detections, when the
  /// server reported it.
  ///
  /// Worth distinguishing from the version the client *asked* for: the web
  /// proxy can override `model_id` server-side so the deployed model can be
  /// switched without rebuilding. Every chart groups by model, so recording the
  /// requested version while a different one ran would show a model swap as a
  /// shelf collapse.
  final String? effectiveModelId;

  DetectionResult({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    this.annotatedImage,
    this.sourceOutputKey,
    this.inferenceTime,
    this.effectiveModelId,
  });

  /// A result with no detections, e.g. an image containing no known products.
  DetectionResult.empty({this.imageWidth = 0, this.imageHeight = 0})
    : detections = const [],
      annotatedImage = null,
      sourceOutputKey = null,
      inferenceTime = null,
      effectiveModelId = null;

  bool get isEmpty => detections.isEmpty;
  bool get isNotEmpty => detections.isNotEmpty;
  int get count => detections.length;

  /// Whether the workflow returned a rendered/annotated image alongside boxes.
  bool get hasAnnotatedImage =>
      annotatedImage != null && annotatedImage!.isNotEmpty;

  /// The distinct class labels present, in first-seen order.
  List<String> get classNames {
    final seen = <String>{};
    return [
      for (final d in detections)
        if (seen.add(d.className)) d.className,
    ];
  }

  /// Share-of-Shelf breakdown for these detections.
  ///
  /// Computed on demand; cached so repeated widget rebuilds don't recompute it.
  ShareOfShelf get shareOfShelf =>
      _shareOfShelf ??= ShareOfShelf.fromDetections(detections);
  ShareOfShelf? _shareOfShelf;

  /// Returns a copy keeping only detections at or above [minConfidence].
  DetectionResult filterByConfidence(double minConfidence) =>
      _copyWithDetections(
        detections.where((d) => d.confidence >= minConfidence).toList(),
      );

  /// Returns a copy keeping only detections whose class is in [classNames],
  /// or is a flavour/variant of one of them (`cappy-orange` for a `cappy`
  /// selection).
  ///
  /// The chip list is sourced from the brand classifier's own classes
  /// (brand-level names like `cappy`, `fanta`), but a detection's real class
  /// is often more specific -- the variant classifiers downstream overwrite
  /// `cappy` with `cappy-orange`, `fanta` with `fanta-redapple`, and so on.
  /// An exact-string match against the chip would then match nothing despite
  /// the product being right there, so a `$root-` prefix counts as the same
  /// selection.
  ///
  /// A null or empty selection means "all products" and returns this result
  /// unchanged -- filtering to nothing would silently blank the screen, which
  /// is never what selecting no filter should mean.
  ///
  /// Share of Shelf is recomputed from the filtered set, so narrowing to two
  /// brands reports their split of *those two* rather than of everything.
  DetectionResult filterByClasses(Set<String>? classNames) {
    if (classNames == null || classNames.isEmpty) return this;
    return _copyWithDetections(
      detections
          .where(
            (d) => classNames.any(
              (root) => d.className == root || d.className.startsWith('$root-'),
            ),
          )
          .toList(),
    );
  }

  /// Returns a copy carrying [detections] in place of the current ones, keeping
  /// the image dimensions and call metadata.
  ///
  /// Share of Shelf is recomputed from the new set rather than carried over.
  DetectionResult withDetections(List<Detection> detections) =>
      _copyWithDetections(detections);

  DetectionResult _copyWithDetections(List<Detection> filtered) {
    return DetectionResult(
      detections: filtered,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      annotatedImage: annotatedImage,
      sourceOutputKey: sourceOutputKey,
      inferenceTime: inferenceTime,
      effectiveModelId: effectiveModelId,
    );
  }

  /// Deliberately omits [annotatedImage] -- printing base64 blobs into logs is
  /// exactly what this class exists to prevent.
  @override
  String toString() =>
      'DetectionResult($count detections, ${imageWidth.toInt()}x'
      '${imageHeight.toInt()}, annotated: $hasAnnotatedImage)';
}
