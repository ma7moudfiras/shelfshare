import 'detection.dart';

/// One class's slice of the shelf.
class ClassShare {
  /// The detected class label, e.g. `coca_cola`.
  final String className;

  /// Combined bounding-box area for this class, in square pixels.
  final double area;

  /// How many boxes of this class contributed to [area].
  final int count;

  /// This class's portion of the total detected area, in the range 0.0 - 1.0.
  final double fraction;

  const ClassShare({
    required this.className,
    required this.area,
    required this.count,
    required this.fraction,
  });

  /// [fraction] expressed as 0 - 100.
  double get percentage => fraction * 100;

  /// Compact label used in the summary line, e.g. `coca_cola: 65%`.
  String get label => '$className: ${percentage.round()}%';

  @override
  String toString() => 'ClassShare($label, count: $count)';
}

/// Share of Shelf: how much of the detected shelf area each brand occupies.
///
/// The measure is intentionally simple and pixel-area based -- for each class,
/// sum the bounding-box areas, then divide by the total detected area across
/// all classes. Overlapping boxes are *not* de-duplicated, so shares are a
/// relative facing-space proxy rather than a true occupancy measurement.
class ShareOfShelf {
  /// Per-class breakdown, ordered largest share first.
  final List<ClassShare> shares;

  /// Summed bounding-box area across every detection, in square pixels.
  final double totalArea;

  const ShareOfShelf({required this.shares, required this.totalArea});

  /// An empty result -- no detections, or no detection with positive area.
  const ShareOfShelf.empty() : shares = const [], totalArea = 0;

  /// Computes the breakdown from a flat list of detections.
  factory ShareOfShelf.fromDetections(List<Detection> detections) {
    if (detections.isEmpty) return const ShareOfShelf.empty();

    final areaByClass = <String, double>{};
    final countByClass = <String, int>{};
    var total = 0.0;

    for (final detection in detections) {
      final area = detection.box.area;
      // Degenerate box: ignore rather than skew totals.
      if (area <= 0) continue;

      areaByClass.update(
        detection.className,
        (existing) => existing + area,
        ifAbsent: () => area,
      );
      countByClass.update(
        detection.className,
        (existing) => existing + 1,
        ifAbsent: () => 1,
      );
      total += area;
    }

    if (total <= 0) return const ShareOfShelf.empty();

    final shares =
        areaByClass.entries
            .map(
              (entry) => ClassShare(
                className: entry.key,
                area: entry.value,
                count: countByClass[entry.key] ?? 0,
                fraction: entry.value / total,
              ),
            )
            .toList()
          // Largest share first; ties broken alphabetically so the order is stable
          // across runs rather than depending on map iteration order.
          ..sort((a, b) {
            final byArea = b.area.compareTo(a.area);
            return byArea != 0 ? byArea : a.className.compareTo(b.className);
          });

    return ShareOfShelf(shares: shares, totalArea: total);
  }

  bool get isEmpty => shares.isEmpty;
  bool get isNotEmpty => shares.isNotEmpty;

  /// Number of distinct classes detected.
  int get classCount => shares.length;

  /// Total number of detections counted across all classes.
  int get detectionCount => shares.fold(0, (sum, share) => sum + share.count);

  /// Single-line breakdown, e.g. `coca_cola: 65% | pepsi: 35%`.
  String get summaryLine =>
      isEmpty ? 'No products detected' : shares.map((s) => s.label).join(' | ');

  @override
  String toString() => 'ShareOfShelf($summaryLine)';
}
