import 'package:shelf_monitor/models/capture_draft.dart';
import 'package:shelf_monitor/models/fridge.dart';
import 'package:shelf_monitor/models/point_of_sale.dart';
import 'package:shelf_monitor/services/market_service.dart';
import 'package:shelf_monitor/services/visit_service.dart';

/// In-memory [MarketService] that records what it was asked to do.
class FakeMarketService implements MarketService {
  List<PointOfSale> marketList;
  List<Fridge> fridgeList;
  Set<String> assigned;

  /// Set to make the next call fail, as an unreachable database would.
  String? failWith;

  final createdMarkets = <({String companyId, String name, String city})>[];
  final createdFridges =
      <({String pointOfSaleId, String name, int sections})>[];
  final assignments = <({String profileId, String posId, bool assigned})>[];

  FakeMarketService({
    this.marketList = const [],
    this.fridgeList = const [],
    Set<String>? assigned,
  }) : assigned = assigned ?? {};

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw MarketFailure(failure);
  }

  @override
  Future<List<PointOfSale>> markets() async {
    _maybeFail();
    return marketList;
  }

  @override
  Future<void> createMarket({
    required String companyId,
    required String name,
    required String city,
    String? area,
    String? address,
  }) async {
    _maybeFail();
    createdMarkets.add((companyId: companyId, name: name, city: city));
  }

  @override
  Future<void> updateMarket({
    required String id,
    required String name,
    required String city,
    String? area,
    String? address,
  }) async => _maybeFail();

  @override
  Future<void> setMarketActive(String id, bool isActive) async => _maybeFail();

  @override
  Future<List<Fridge>> fridges(String pointOfSaleId) async {
    _maybeFail();
    return fridgeList;
  }

  @override
  Future<void> createFridge({
    required String companyId,
    required String pointOfSaleId,
    required String name,
    double? widthCm,
    double? heightCm,
    int sectionCount = 1,
  }) async {
    _maybeFail();
    createdFridges.add((
      pointOfSaleId: pointOfSaleId,
      name: name,
      sections: sectionCount,
    ));
  }

  @override
  Future<void> setFridgeActive(String id, bool isActive) async => _maybeFail();

  @override
  Future<Set<String>> assignedRepIds(String pointOfSaleId) async {
    _maybeFail();
    return assigned;
  }

  @override
  Future<void> setRepAssignment({
    required String profileId,
    required String pointOfSaleId,
    required bool assigned,
  }) async {
    _maybeFail();
    assignments.add((
      profileId: profileId,
      posId: pointOfSaleId,
      assigned: assigned,
    ));
    if (assigned) {
      this.assigned = {...this.assigned, profileId};
    } else {
      this.assigned = {...this.assigned}..remove(profileId);
    }
  }
}

/// In-memory [VisitService] that records everything it was asked to store.
class FakeVisitService implements VisitService {
  List<PointOfSale> marketList;
  List<Fridge> fridgeList;

  String? failWith;

  /// Set to make only [recordCapture] fail, leaving loads working.
  String? failCaptureWith;

  var startedVisits = 0;
  final submitted = <String>[];
  final captures =
      <
        ({
          String visitId,
          String fridgeId,
          String? sectionId,
          CaptureDraft draft,
          String modelId,
        })
      >[];

  FakeVisitService({this.marketList = const [], this.fridgeList = const []});

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw VisitFailure(failure);
  }

  @override
  Future<List<PointOfSale>> assignedMarkets() async {
    _maybeFail();
    return marketList;
  }

  @override
  Future<List<Fridge>> fridges(String pointOfSaleId) async {
    _maybeFail();
    return fridgeList;
  }

  @override
  Future<String> startVisit({
    required String companyId,
    required String pointOfSaleId,
  }) async {
    _maybeFail();
    startedVisits++;
    return 'visit-$pointOfSaleId';
  }

  @override
  Future<String> recordCapture({
    required String visitId,
    required String companyId,
    required String fridgeId,
    String? fridgeSectionId,
    required String modelId,
    required double confidenceThreshold,
    required CaptureDraft draft,
  }) async {
    final failure = failCaptureWith;
    if (failure != null) throw VisitFailure(failure);
    captures.add((
      visitId: visitId,
      fridgeId: fridgeId,
      sectionId: fridgeSectionId,
      draft: draft,
      modelId: modelId,
    ));
    return 'capture-${captures.length}';
  }

  @override
  Future<void> submitVisit(String visitId) async {
    _maybeFail();
    submitted.add(visitId);
  }

  @override
  Future<int> captureCount(String visitId) async => captures.length;
}

/// A market with sensible defaults, so tests only state what they care about.
PointOfSale market({
  String id = 'pos-1',
  String name = 'Carrefour City',
  String city = 'Ramallah',
  String? area,
  int? fridgeCount,
}) => PointOfSale(
  id: id,
  companyId: 'c-unipal',
  name: name,
  city: city,
  area: area,
  fridgeCount: fridgeCount,
);

/// A fridge with [sectionCount] sections.
Fridge fridge({
  String id = 'fridge-1',
  String name = 'Entrance cooler',
  int sectionCount = 1,
}) => Fridge(
  id: id,
  companyId: 'c-unipal',
  pointOfSaleId: 'pos-1',
  name: name,
  qrToken: 'ABC123',
  sections: [
    for (var i = 1; i <= sectionCount; i++)
      FridgeSection(
        id: '$id-s$i',
        fridgeId: id,
        label: sectionCount == 1 ? 'Main' : 'Shelf $i',
        position: i,
      ),
  ],
);
