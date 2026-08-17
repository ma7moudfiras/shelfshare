/// One submitted visit at a market: who recorded it, when, and how much.
///
/// Deliberately carries only [repId], not a name -- resolving that to a
/// person is a join against `profiles`/the company's rep list, which the
/// caller (already holding that list, e.g. `MarketDetailScreen`) is better
/// placed to do than a second round-trip here.
class MarketVisitSummary {
  final String visitId;
  final String repId;
  final DateTime? submittedAt;
  final int captureCount;

  /// Sum of each capture's kept `detection_count` -- the count a rep signed
  /// off on, not the raw model output before corrections.
  final int detectionCount;

  const MarketVisitSummary({
    required this.visitId,
    required this.repId,
    required this.submittedAt,
    required this.captureCount,
    required this.detectionCount,
  });

  factory MarketVisitSummary.fromJson(Map<String, dynamic> json) {
    final captures = json['captures'];
    var captureCount = 0;
    var detectionCount = 0;
    if (captures is List) {
      captureCount = captures.length;
      for (final capture in captures) {
        if (capture is Map) {
          detectionCount += (capture['detection_count'] as num?)?.toInt() ?? 0;
        }
      }
    }

    final submittedRaw = json['submitted_at'] as String?;

    return MarketVisitSummary(
      visitId: json['id'] as String,
      repId: json['rep_id'] as String? ?? '',
      submittedAt: submittedRaw == null
          ? null
          : DateTime.tryParse(submittedRaw),
      captureCount: captureCount,
      detectionCount: detectionCount,
    );
  }
}
