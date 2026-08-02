import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/capture_draft.dart';
import '../models/fridge.dart';
import '../models/point_of_sale.dart';

/// Raised when recording a visit or a capture fails.
class VisitFailure implements Exception {
  final String message;
  const VisitFailure(this.message);

  @override
  String toString() => message;
}

/// What a sales rep does in the field: open a visit, record captures against
/// the fridges in one market, then submit.
///
/// Until this existed the app detected products and forgot them. Everything
/// downstream -- share of shelf, coverage, trends -- reads tables that nothing
/// was writing to, so the dashboards had nothing to show and could not have
/// been built.
abstract class VisitService {
  /// Markets this rep is assigned to.
  ///
  /// No filter is applied here on purpose. The read policy on
  /// `points_of_sale` already restricts a rep to `assigned_pos_ids()`, so
  /// filtering again in the client would duplicate a rule that has to live in
  /// the database anyway.
  Future<List<PointOfSale>> assignedMarkets();

  /// Fridges in one market, each with its sections.
  Future<List<Fridge>> fridges(String pointOfSaleId);

  /// Opens a visit, or returns the one already open for this rep at this market.
  ///
  /// Reusing an in-progress visit matters: a rep who backs out to fix a photo
  /// and comes back should not leave a trail of abandoned visits that make
  /// coverage reporting meaningless.
  Future<String> startVisit({
    required String companyId,
    required String pointOfSaleId,
  });

  /// Writes one capture and its detections.
  ///
  /// Returns the new capture's id.
  Future<String> recordCapture({
    required String visitId,
    required String companyId,
    required String fridgeId,
    String? fridgeSectionId,
    required String modelId,
    required double confidenceThreshold,
    required CaptureDraft draft,
  });

  /// Marks the visit finished. Reps cannot change it afterwards.
  Future<void> submitVisit(String visitId);

  /// How many captures a visit already holds, so a rep can see progress.
  Future<int> captureCount(String visitId);
}

class SupabaseVisitService implements VisitService {
  final SupabaseClient _client;

  SupabaseVisitService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<T> _guard<T>(Future<T> Function() action, String whatFailed) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw VisitFailure(e.message);
    } catch (_) {
      throw VisitFailure('$whatFailed Check your connection and try again.');
    }
  }

  @override
  Future<List<PointOfSale>> assignedMarkets() => _guard(() async {
    final rows = await _client
        .from('points_of_sale')
        .select(
          'id, company_id, name, city, area, address, latitude, longitude, '
          'is_active, fridges(count)',
        )
        .eq('is_active', true)
        .order('name');
    return rows.map(PointOfSale.fromJson).toList();
  }, 'Could not load your markets.');

  @override
  Future<List<Fridge>> fridges(String pointOfSaleId) => _guard(() async {
    final rows = await _client
        .from('fridges')
        .select(
          'id, company_id, point_of_sale_id, name, qr_token, width_cm, '
          'height_cm, is_active, fridge_sections(id, fridge_id, label, position)',
        )
        .eq('point_of_sale_id', pointOfSaleId)
        .eq('is_active', true)
        .order('name');
    return rows.map(Fridge.fromJson).toList();
  }, 'Could not load the fridges here.');

  @override
  Future<String> startVisit({
    required String companyId,
    required String pointOfSaleId,
  }) => _guard(() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const VisitFailure('You are not signed in.');

    final existing = await _client
        .from('visits')
        .select('id')
        .eq('point_of_sale_id', pointOfSaleId)
        .eq('rep_id', user.id)
        .eq('status', 'in_progress')
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final inserted = await _client
        .from('visits')
        .insert({
          'company_id': companyId,
          'point_of_sale_id': pointOfSaleId,
          'rep_id': user.id,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }, 'Could not start this visit.');

  @override
  Future<String> recordCapture({
    required String visitId,
    required String companyId,
    required String fridgeId,
    String? fridgeSectionId,
    required String modelId,
    required double confidenceThreshold,
    required CaptureDraft draft,
  }) => _guard(() async {
    final kept = draft.entries.where((e) => e.counts).toList();
    final meanConfidence = _meanModelConfidence(kept);

    final capture = await _client
        .from('captures')
        .insert({
          'company_id': companyId,
          'visit_id': visitId,
          'fridge_id': fridgeId,
          'fridge_section_id': fridgeSectionId,
          'model_id': modelId,
          'confidence_threshold': confidenceThreshold,
          'identified_by': 'manual',
          // The submitted count, not the raw one. Rejected boxes stay in
          // `detections` so the model's original answer is still recoverable,
          // but the headline number is what the person standing at the shelf
          // signed off on.
          'detection_count': kept.length,
          'mean_confidence': meanConfidence,
          'edit_count': draft.isEdited ? 1 : 0,
          'edited_by': draft.isEdited ? _client.auth.currentUser?.id : null,
        })
        .select('id')
        .single();

    final captureId = capture['id'] as String;

    if (draft.entries.isNotEmpty) {
      await _client.from('detections').insert([
        for (final entry in draft.entries)
          {
            'capture_id': captureId,
            'roboflow_class': entry.detection.className,
            // A manual entry has no probability. Storing null keeps it out of
            // confidence averages instead of dragging them towards zero.
            'confidence': entry.origin == DetectionOrigin.manual
                ? null
                : entry.detection.confidence,
            'x': entry.detection.box.centerX,
            'y': entry.detection.box.centerY,
            'width': entry.detection.box.width,
            'height': entry.detection.box.height,
            'origin': entry.origin.dbValue,
            'removed': entry.removed,
            'original_class': entry.originalClass,
          },
      ]);
    }

    return captureId;
  }, 'Could not save this capture.');

  @override
  Future<void> submitVisit(String visitId) => _guard(
    () => _client
        .from('visits')
        .update({
          'status': 'submitted',
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', visitId),
    'Could not submit this visit.',
  );

  @override
  Future<int> captureCount(String visitId) => _guard(() async {
    final rows = await _client
        .from('captures')
        .select('id')
        .eq('visit_id', visitId)
        .count(CountOption.exact);
    return rows.count;
  }, 'Could not check this visit.');

  /// Mean confidence across kept *model* detections.
  ///
  /// Manual entries are excluded rather than counted as zero, which would make
  /// a well-corrected capture look like a low-quality one.
  static double? _meanModelConfidence(List<DraftDetection> kept) {
    final scores = [
      for (final entry in kept)
        if (entry.origin == DetectionOrigin.model) entry.detection.confidence,
    ];
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}
