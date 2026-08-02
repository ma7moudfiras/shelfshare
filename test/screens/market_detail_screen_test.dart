import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/user_profile.dart';
import 'package:shelf_monitor/screens/market_detail_screen.dart';
import 'package:shelf_monitor/theme/app_theme.dart';

import '../support/fake_services.dart';

UserProfile rep(String id, String name) => UserProfile(
  id: id,
  role: UserRole.salesRep,
  companyId: 'c-unipal',
  fullName: name,
  email: '$id@unipal.com',
);

void main() {
  Future<FakeMarketService> pumpDetail(
    WidgetTester tester, {
    FakeMarketService? service,
    List<UserProfile> reps = const [],
    Size size = const Size(500, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final markets = service ?? FakeMarketService(fridgeList: [fridge()]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MarketDetailScreen(
          market: market(name: 'Carrefour City', city: 'Ramallah', area: 'Al-Masyoun'),
          marketService: markets,
          reps: reps,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return markets;
  }

  testWidgets('shows where the market is and what is in it', (tester) async {
    await pumpDetail(
      tester,
      service: FakeMarketService(
        fridgeList: [fridge(name: 'Entrance cooler', sectionCount: 2)],
      ),
    );

    expect(find.text('Carrefour City'), findsOneWidget);
    expect(find.text('Ramallah · Al-Masyoun'), findsOneWidget);
    expect(find.text('Entrance cooler'), findsOneWidget);
    expect(find.textContaining('2 shelves'), findsOneWidget);
    // The scan code is printed onto a label, so it has to be readable here.
    expect(find.text('ABC123'), findsOneWidget);
  });

  // Assignment is the whole ballgame: assigned_pos_ids() backs the read policy
  // on markets and fridges and the insert policy on visits, so an unassigned
  // rep cannot see this market at all, let alone record against it.
  testWidgets('assigning a rep is recorded', (tester) async {
    final markets = await pumpDetail(
      tester,
      reps: [rep('r1', 'Sara Qasim'), rep('r2', 'Omar Nasser')],
    );

    expect(find.text('Sara Qasim'), findsOneWidget);
    expect(find.text('Omar Nasser'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sara Qasim'));
    await tester.pumpAndSettle();

    expect(markets.assignments, [
      (profileId: 'r1', posId: 'pos-1', assigned: true),
    ]);
  });

  testWidgets('unassigning a rep is recorded', (tester) async {
    final markets = await pumpDetail(
      tester,
      service: FakeMarketService(fridgeList: [fridge()], assigned: {'r1'}),
      reps: [rep('r1', 'Sara Qasim')],
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sara Qasim'));
    await tester.pumpAndSettle();

    expect(markets.assignments.single.assigned, isFalse);
  });

  testWidgets('with no reps on the team it says what to do', (tester) async {
    await pumpDetail(tester);
    expect(find.textContaining('No sales reps on the team yet'), findsOneWidget);
  });

  // A market with no fridges is one a rep can reach and then find nothing to
  // photograph, so it is worth flagging at setup rather than at the shelf.
  testWidgets('a market with no fridges is called out', (tester) async {
    await pumpDetail(
      tester,
      service: FakeMarketService(fridgeList: const []),
    );

    expect(find.textContaining('No fridges here yet'), findsOneWidget);
  });

  testWidgets('adding a fridge asks for its shelves and records them', (
    tester,
  ) async {
    final markets = await pumpDetail(
      tester,
      service: FakeMarketService(fridgeList: const []),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fridge name'),
      'Back aisle',
    );
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add fridge'));
    await tester.pumpAndSettle();

    expect(markets.createdFridges, [
      (pointOfSaleId: 'pos-1', name: 'Back aisle', sections: 3),
    ]);
  });

  testWidgets('a fridge needs a name', (tester) async {
    final markets = await pumpDetail(
      tester,
      service: FakeMarketService(fridgeList: const []),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add fridge'));
    await tester.pumpAndSettle();

    expect(find.text('Give this fridge a name'), findsOneWidget);
    expect(markets.createdFridges, isEmpty);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final markets = FakeMarketService()..failWith = 'Permission denied.';
    await pumpDetail(tester, service: markets);

    expect(find.text('Permission denied.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
