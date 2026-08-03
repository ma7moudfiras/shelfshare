import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/screens/rep_visit_screen.dart';
import 'package:shelf_monitor/theme/app_theme.dart';

import '../support/fake_services.dart';

void main() {
  Future<FakeVisitService> pumpVisit(
    WidgetTester tester, {
    FakeVisitService? service,
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final visits = service ?? FakeVisitService(fridgeList: [fridge()]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: RepVisitScreen(
          market: market(name: 'Carrefour City', city: 'Ramallah'),
          companyId: 'c-unipal',
          visitService: visits,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return visits;
  }

  // The visit is what the database checks before it accepts a capture, so it
  // has to exist before the rep reaches a shelf -- not on the first photo.
  testWidgets('opens a visit as soon as the market is entered', (tester) async {
    final visits = await pumpVisit(tester);
    expect(visits.startedVisits, 1);
  });

  testWidgets('lists the fridges to photograph', (tester) async {
    await pumpVisit(
      tester,
      service: FakeVisitService(
        fridgeList: [
          fridge(id: 'f1', name: 'Entrance cooler'),
          fridge(id: 'f2', name: 'Back aisle'),
        ],
      ),
    );

    expect(find.text('Entrance cooler'), findsOneWidget);
    expect(find.text('Back aisle'), findsOneWidget);
    expect(find.text('Carrefour City'), findsOneWidget);
    expect(find.text('Ramallah'), findsOneWidget);
  });

  // Asking someone to pick "Shelf 1 of 1" teaches them to tap without reading,
  // which is the habit that produces bad data.
  testWidgets('a single-shelf fridge offers one plain shutter', (tester) async {
    await pumpVisit(
      tester,
      service: FakeVisitService(fridgeList: [fridge(sectionCount: 1)]),
    );

    expect(find.text('Photograph'), findsOneWidget);
    expect(find.text('Main'), findsNothing);
  });

  testWidgets('a multi-shelf fridge offers one shutter per shelf', (
    tester,
  ) async {
    await pumpVisit(
      tester,
      service: FakeVisitService(fridgeList: [fridge(sectionCount: 3)]),
    );

    expect(find.text('Shelf 1'), findsOneWidget);
    expect(find.text('Shelf 2'), findsOneWidget);
    expect(find.text('Shelf 3'), findsOneWidget);
    expect(find.text('Photograph'), findsNothing);
  });

  testWidgets('submitting asks first, then records it', (tester) async {
    final visits = await pumpVisit(tester);

    await tester.tap(find.text('Submit visit'));
    await tester.pumpAndSettle();

    expect(find.text('Submit this visit?'), findsOneWidget);
    // With nothing captured, the warning has to be explicit rather than a
    // generic confirmation.
    expect(find.textContaining('nothing in it'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(visits.submitted, ['visit-pos-1']);
  });

  testWidgets('backing out of the confirmation records nothing', (
    tester,
  ) async {
    final visits = await pumpVisit(tester);

    await tester.tap(find.text('Submit visit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();

    expect(visits.submitted, isEmpty);
  });

  // A market with no fridges is a setup problem, and the rep is not the person
  // who can fix it. Say who is.
  testWidgets('a market with no fridges explains itself', (tester) async {
    await pumpVisit(tester, service: FakeVisitService(fridgeList: const []));

    expect(find.text('No fridges recorded here'), findsOneWidget);
    expect(find.textContaining('administrator'), findsOneWidget);
    // Nothing to submit, so no submit bar.
    expect(find.text('Submit visit'), findsNothing);
  });

  testWidgets('a failed load offers a retry rather than a blank screen', (
    tester,
  ) async {
    final visits = FakeVisitService()..failWith = 'Network unreachable.';
    await pumpVisit(tester, service: visits);

    expect(find.text('Network unreachable.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('works on a desktop window', (tester) async {
    await pumpVisit(tester, size: const Size(1440, 900));
    expect(find.text('Entrance cooler'), findsOneWidget);
    expect(find.text('Submit visit'), findsOneWidget);
  });
}
