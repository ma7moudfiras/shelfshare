import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/brand_share_of_shelf.dart';
import '../models/fridge.dart';
import '../models/market_visit_summary.dart';
import '../models/point_of_sale.dart';

/// Raised when a market operation is refused or fails.
class MarketFailure implements Exception {
  final String message;
  const MarketFailure(this.message);

  @override
  String toString() => message;
}

/// Markets, the fridges inside them, and which reps cover them.
///
/// Everything here is scoped by Row Level Security rather than by any check in
/// this file: `pos_write` admits platform admins and a company admin acting on
/// their own company, and nothing else. A rep calling these would simply read
/// an empty list.
abstract class MarketService {
  /// Markets visible to the caller, each carrying its fridge count.
  Future<List<PointOfSale>> markets();

  Future<void> createMarket({
    required String companyId,
    required String name,
    required String city,
    String? area,
    String? address,
  });

  Future<void> updateMarket({
    required String id,
    required String name,
    required String city,
    String? area,
    String? address,
  });

  /// Retires a market without deleting it, so historic visits keep their
  /// subject. Deleting would orphan or cascade real measurements.
  Future<void> setMarketActive(String id, bool isActive);

  /// Fridges in one market, each with its sections.
  Future<List<Fridge>> fridges(String pointOfSaleId);

  Future<void> createFridge({
    required String companyId,
    required String pointOfSaleId,
    required String name,
    double? widthCm,
    double? heightCm,
    int sectionCount = 1,
  });

  Future<void> setFridgeActive(String id, bool isActive);

  /// Profile ids of reps currently assigned to [pointOfSaleId].
  Future<Set<String>> assignedRepIds(String pointOfSaleId);

  /// Adds or removes one rep's assignment to a market.
  ///
  /// This is not cosmetic. `assigned_pos_ids()` backs the read policy on
  /// markets and fridges *and* the insert policy on visits, so an unassigned
  /// rep cannot see a market, let alone record against it.
  Future<void> setRepAssignment({
    required String profileId,
    required String pointOfSaleId,
    required bool assigned,
  });

  /// Submitted visits recorded at this market, most recent first.
  ///
  /// This is the only place a company admin can see what a rep actually
  /// captured -- until this existed, data flowed into `visits`/`captures`/
  /// `detections` with no screen reading any of it back.
  Future<List<MarketVisitSummary>> recentVisits(
    String pointOfSaleId, {
    int limit = 20,
  });

  /// Brand -> variant breakdown across every kept detection from every
  /// submitted visit at this market.
  Future<BrandShareOfShelf> shareOfShelf(String pointOfSaleId);
}

class SupabaseMarketService implements MarketService {
  final SupabaseClient _client;

  SupabaseMarketService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static final _random = Random.secure();

  /// Token printed on a fridge label and scanned to identify it.
  ///
  /// Unique in the database, so a collision is a failed insert rather than a
  /// mislabelled fridge; 64 bits from a secure source makes that unreachable in
  /// practice. Ambiguous characters are left out because these get read aloud
  /// and typed by hand when a label is damaged.
  static String _newQrToken() {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(
      13,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  Future<T> _guard<T>(Future<T> Function() action, String whatFailed) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      // The database's own message distinguishes "not allowed" from "that name
      // is taken", which a generic string would flatten into one useless line.
      throw MarketFailure(e.message);
    } catch (_) {
      throw MarketFailure('$whatFailed Check your connection and try again.');
    }
  }

  @override
  Future<List<PointOfSale>> markets() => _guard(() async {
    final rows = await _client
        .from('points_of_sale')
        .select(
          'id, company_id, name, city, area, address, latitude, longitude, '
          'is_active, fridges(count)',
        )
        .order('name');
    return rows.map(PointOfSale.fromJson).toList();
  }, 'Could not load markets.');

  @override
  Future<void> createMarket({
    required String companyId,
    required String name,
    required String city,
    String? area,
    String? address,
  }) => _guard(
    () => _client.from('points_of_sale').insert({
      'company_id': companyId,
      'name': name.trim(),
      'city': city.trim(),
      'area': _trimToNull(area),
      'address': _trimToNull(address),
    }),
    'Could not add that market.',
  );

  @override
  Future<void> updateMarket({
    required String id,
    required String name,
    required String city,
    String? area,
    String? address,
  }) => _guard(
    () => _client
        .from('points_of_sale')
        .update({
          'name': name.trim(),
          'city': city.trim(),
          'area': _trimToNull(area),
          'address': _trimToNull(address),
        })
        .eq('id', id),
    'Could not save that market.',
  );

  @override
  Future<void> setMarketActive(String id, bool isActive) => _guard(
    () => _client
        .from('points_of_sale')
        .update({'is_active': isActive})
        .eq('id', id),
    'Could not change that market.',
  );

  @override
  Future<List<Fridge>> fridges(String pointOfSaleId) => _guard(() async {
    final rows = await _client
        .from('fridges')
        .select(
          'id, company_id, point_of_sale_id, name, qr_token, width_cm, '
          'height_cm, is_active, fridge_sections(id, fridge_id, label, position)',
        )
        .eq('point_of_sale_id', pointOfSaleId)
        .order('name');
    return rows.map(Fridge.fromJson).toList();
  }, 'Could not load fridges.');

  @override
  Future<void> createFridge({
    required String companyId,
    required String pointOfSaleId,
    required String name,
    double? widthCm,
    double? heightCm,
    int sectionCount = 1,
  }) => _guard(() async {
    final inserted = await _client
        .from('fridges')
        .insert({
          'company_id': companyId,
          'point_of_sale_id': pointOfSaleId,
          'name': name.trim(),
          'qr_token': _newQrToken(),
          'width_cm': widthCm,
          'height_cm': heightCm,
        })
        .select('id')
        .single();

    if (sectionCount <= 1) return;

    // A trigger already created one section called "Main". Rename it and add
    // the rest, so a multi-shelf fridge reads as "Shelf 1..n" rather than
    // "Main" followed by a gap.
    final fridgeId = inserted['id'] as String;
    await _client
        .from('fridge_sections')
        .update({'label': 'Shelf 1'})
        .eq('fridge_id', fridgeId);
    await _client.from('fridge_sections').insert([
      for (var position = 2; position <= sectionCount; position++)
        {
          'fridge_id': fridgeId,
          'label': 'Shelf $position',
          'position': position,
        },
    ]);
  }, 'Could not add that fridge.');

  @override
  Future<void> setFridgeActive(String id, bool isActive) => _guard(
    () => _client.from('fridges').update({'is_active': isActive}).eq('id', id),
    'Could not change that fridge.',
  );

  @override
  Future<Set<String>> assignedRepIds(String pointOfSaleId) => _guard(() async {
    final rows = await _client
        .from('rep_assignments')
        .select('profile_id')
        .eq('point_of_sale_id', pointOfSaleId);
    return {for (final row in rows) row['profile_id'] as String};
  }, 'Could not load who covers this market.');

  @override
  Future<void> setRepAssignment({
    required String profileId,
    required String pointOfSaleId,
    required bool assigned,
  }) => _guard(() async {
    if (assigned) {
      await _client.from('rep_assignments').insert({
        'profile_id': profileId,
        'point_of_sale_id': pointOfSaleId,
      });
    } else {
      await _client
          .from('rep_assignments')
          .delete()
          .eq('profile_id', profileId)
          .eq('point_of_sale_id', pointOfSaleId);
    }
  }, 'Could not change that assignment.');

  @override
  Future<List<MarketVisitSummary>> recentVisits(
    String pointOfSaleId, {
    int limit = 20,
  }) => _guard(() async {
    final rows = await _client
        .from('visits')
        .select('id, rep_id, submitted_at, captures(id, detection_count)')
        .eq('point_of_sale_id', pointOfSaleId)
        .eq('status', 'submitted')
        .order('submitted_at', ascending: false)
        .limit(limit);
    return rows.map(MarketVisitSummary.fromJson).toList();
  }, 'Could not load submissions for this market.');

  @override
  Future<BrandShareOfShelf> shareOfShelf(String pointOfSaleId) =>
      _guard(() async {
        final rows = await _client
            .from('visits')
            .select('captures(detections(roboflow_class, removed))')
            .eq('point_of_sale_id', pointOfSaleId)
            .eq('status', 'submitted');

        final classNames = <String>[];
        for (final visit in rows) {
          final captures = visit['captures'];
          if (captures is! List) continue;
          for (final capture in captures) {
            final detections = capture is Map ? capture['detections'] : null;
            if (detections is! List) continue;
            for (final detection in detections) {
              if (detection is! Map) continue;
              // Rejected boxes stay in the table so the model's original
              // answer is recoverable, but they were not real products on
              // the shelf and must not count toward the share.
              if (detection['removed'] == true) continue;
              final className = detection['roboflow_class'] as String?;
              if (className != null && className.isNotEmpty) {
                classNames.add(className);
              }
            }
          }
        }

        return BrandShareOfShelf.fromClassNames(classNames);
      }, 'Could not load the share of shelf for this market.');

  /// Blank optional text is stored as null, so "not recorded" is one value
  /// rather than two that sort and compare differently.
  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
