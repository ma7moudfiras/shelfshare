import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/capture_aspect_ratio.dart';
import 'package:shelf_monitor/models/model_option.dart';
import 'package:shelf_monitor/widgets/model_picker.dart';

List<ModelOption> modelsCount(int n) => [
  for (var v = n; v >= 1; v--)
    ModelOption(
      modelId: 'aystro-project/$v',
      version: v,
      name: 'Version $v',
      images: 100 + v,
      map50: 80 + v.toDouble(),
    ),
];

Future<void> pumpPicker(
  WidgetTester tester, {
  required List<ModelOption> models,
  String? selected,
  void Function(String)? onSelected,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ModelPicker(
            models: models,
            selectedModelId: selected,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ModelPicker', () {
    testWidgets('collapses to three versions with a Show all action', (
      tester,
    ) async {
      await pumpPicker(tester, models: modelsCount(10));

      expect(find.text('Version 10'), findsOneWidget);
      expect(find.text('Version 9'), findsOneWidget);
      expect(find.text('Version 8'), findsOneWidget);
      // Ten near-identical rows is a wall of text; the rest stay behind a tap.
      expect(find.text('Version 7'), findsNothing);
      expect(find.text('Show all 10'), findsOneWidget);
    });

    testWidgets('expands and collapses again', (tester) async {
      await pumpPicker(tester, models: modelsCount(10));

      await tester.tap(find.text('Show all 10'));
      await tester.pumpAndSettle();
      expect(find.text('Version 1'), findsOneWidget);

      // Ten rows push the toggle past the bottom of the test viewport.
      await tester.ensureVisible(find.text('Show fewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show fewer'));
      await tester.pumpAndSettle();
      expect(find.text('Version 1'), findsNothing);
    });

    testWidgets('no Show all action when everything already fits', (
      tester,
    ) async {
      await pumpPicker(tester, models: modelsCount(3));

      expect(find.textContaining('Show all'), findsNothing);
    });

    // A selection the user cannot see reads as the app having forgotten it.
    testWidgets('starts expanded when the selection is in the hidden tail', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        models: modelsCount(10),
        selected: 'aystro-project/2',
      );

      expect(find.text('Version 2'), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);
    });

    testWidgets('reports the tapped version', (tester) async {
      String? picked;
      await pumpPicker(
        tester,
        models: modelsCount(5),
        onSelected: (id) => picked = id,
      );

      await tester.tap(find.text('Version 4'));
      expect(picked, 'aystro-project/4');
    });

    testWidgets('marks the newest version', (tester) async {
      await pumpPicker(tester, models: modelsCount(5));

      expect(find.text('Newest'), findsOneWidget);
    });

    testWidgets('explains itself when the catalog is unavailable', (
      tester,
    ) async {
      await pumpPicker(tester, models: const []);

      expect(find.textContaining('unavailable'), findsOneWidget);
    });
  });

  group('CaptureAspectRatio', () {
    test('full does not crop; the rest do', () {
      expect(CaptureAspectRatio.full.cropsFrame, isFalse);
      expect(CaptureAspectRatio.square.cropsFrame, isTrue);
      expect(CaptureAspectRatio.fourThree.cropsFrame, isTrue);
      expect(CaptureAspectRatio.sixteenNine.cropsFrame, isTrue);
    });

    test('ratios are portrait-first', () {
      // The capture screen is portrait, so 4:3 means 3 wide by 4 tall.
      expect(CaptureAspectRatio.square.ratio, 1.0);
      expect(CaptureAspectRatio.fourThree.ratio, closeTo(0.75, 1e-9));
      expect(CaptureAspectRatio.sixteenNine.ratio, closeTo(0.5625, 1e-9));
    });

    test('full falls back to the supplied ratio for layout', () {
      expect(CaptureAspectRatio.full.effectiveRatio(1.75), 1.75);
      expect(CaptureAspectRatio.square.effectiveRatio(1.75), 1.0);
    });
  });
}
