import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/bounding_box.dart';
import 'package:shelf_monitor/models/capture_draft.dart';
import 'package:shelf_monitor/models/detection.dart';
import 'package:shelf_monitor/models/detection_result.dart';
import 'package:shelf_monitor/screens/capture_review_screen.dart';
import 'package:shelf_monitor/theme/app_theme.dart';

Uint8List sampleJpegBytes() => Uint8List.fromList(
  File('test/fixtures/sample_shelf.jpg').readAsBytesSync(),
);

Detection detection(String className, {double confidence = 0.9}) => Detection(
  className: className,
  confidence: confidence,
  box: const BoundingBox(centerX: 100, centerY: 100, width: 40, height: 40),
);

void main() {
  /// Pumps the review screen and hands back the drafts it saved.
  Future<List<CaptureDraft>> pumpReview(
    WidgetTester tester, {
    required List<Detection> detections,
    List<String> availableClasses = const [],
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final saved = <CaptureDraft>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: CaptureReviewScreen(
          imageBytes: sampleJpegBytes(),
          initialDraft: CaptureDraft.fromResult(
            DetectionResult(
              detections: detections,
              imageWidth: 1000,
              imageHeight: 1000,
            ),
          ),
          targetLabel: 'Entrance cooler · Shelf 2',
          availableClasses: availableClasses,
          onSave: (draft) async => saved.add(draft),
        ),
      ),
    );
    // Settle the route transition: until it finishes the page sits behind an
    // animated opacity in the overlay and taps land on nothing.
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('shows what will be recorded, and where', (tester) async {
    await pumpReview(
      tester,
      detections: [detection('cola'), detection('cola'), detection('pepsi')],
    );

    expect(find.text('Entrance cooler · Shelf 2'), findsOneWidget);
    expect(find.text('3 facings will be recorded'), findsOneWidget);
    // Each class appears twice: once in the Share of Shelf breakdown, once as
    // an editable row.
    expect(find.text('cola'), findsWidgets);
    expect(find.text('pepsi'), findsWidgets);
  });

  testWidgets('minus lowers the count that will be recorded', (tester) async {
    final saved = await pumpReview(
      tester,
      detections: [detection('cola'), detection('cola')],
    );

    await tester.tap(find.byKey(const ValueKey('remove-cola')));
    await tester.pump();

    expect(find.text('1 facing will be recorded'), findsOneWidget);

    await tester.tap(find.text('Save capture'));
    await tester.pump();

    expect(saved.single.keptCount, 1);
    // The rejected prediction still travels to the database.
    expect(saved.single.entries, hasLength(2));
    expect(saved.single.removedCount, 1);
  });

  testWidgets('plus adds a facing the model missed', (tester) async {
    final saved = await pumpReview(tester, detections: [detection('cola')]);

    await tester.tap(find.byKey(const ValueKey('add-cola')));
    await tester.pump();

    expect(find.text('2 facings will be recorded'), findsOneWidget);

    await tester.tap(find.text('Save capture'));
    await tester.pump();

    expect(saved.single.addedCount, 1);
    expect(saved.single.entries.last.origin, DetectionOrigin.manual);
  });

  testWidgets('an untouched capture saves exactly what the model said', (
    tester,
  ) async {
    final saved = await pumpReview(
      tester,
      detections: [detection('cola'), detection('pepsi')],
    );

    await tester.tap(find.text('Save capture'));
    await tester.pump();

    expect(saved.single.isEdited, isFalse);
    expect(saved.single.keptCount, 2);
  });

  testWidgets('says what was changed before it is committed', (tester) async {
    await pumpReview(tester, detections: [detection('cola')]);

    await tester.tap(find.byKey(const ValueKey('remove-cola')));
    await tester.pump();

    expect(find.textContaining('1 rejected'), findsOneWidget);
  });

  // The case that matters most: a competitor taking the whole shelf looks
  // exactly like a detection failure until a rep says otherwise, so a product
  // must be addable even when none of it was found.
  testWidgets('a product can be added when nothing was detected', (
    tester,
  ) async {
    final saved = await pumpReview(
      tester,
      detections: const [],
      availableClasses: const ['cola', 'pepsi'],
    );

    expect(find.text('0 facings will be recorded'), findsOneWidget);

    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pepsi').last);
    await tester.pumpAndSettle();

    expect(find.text('1 facing will be recorded'), findsOneWidget);

    await tester.tap(find.text('Save capture'));
    await tester.pump();

    expect(saved.single.entries.single.detection.className, 'pepsi');
    expect(saved.single.entries.single.origin, DetectionOrigin.manual);
  });

  testWidgets('offers nothing to add when no product list is available', (
    tester,
  ) async {
    await pumpReview(tester, detections: const []);
    expect(find.text('Add product'), findsNothing);
  });

  testWidgets('saving twice in a row records one capture', (tester) async {
    final saved = await pumpReview(tester, detections: [detection('cola')]);

    await tester.tap(find.text('Save capture'));
    await tester.pump();

    expect(saved, hasLength(1));
  });

  testWidgets('lays out side by side on a desktop window', (tester) async {
    await pumpReview(
      tester,
      detections: [detection('cola')],
      size: const Size(1440, 900),
    );

    expect(find.text('1 facing will be recorded'), findsOneWidget);
    expect(find.text('cola'), findsWidgets);
  });
}
