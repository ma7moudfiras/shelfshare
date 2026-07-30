import 'dart:ui' show PictureRecorder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/capture_aspect_ratio.dart';
import 'package:shelf_monitor/widgets/camera_stage.dart';

/// These guard the reason the viewfinder went permanently black twice.
///
/// A live [CameraPreview] is a platform view. On web it is a real `<video>`
/// element parked in a DOM slot, and the engine re-creates that slot whenever
/// the shape of the scene around it changes -- either because the preview was
/// re-parented in the widget tree, or because the number of layers composited
/// over it changed. On Safari the orphaned element never recovers, so the
/// preview stayed black even after switching the ratio back to Full.
///
/// [CameraStage] exists so that rule has one home and can be tested with a
/// stand-in preview, which is the only way to test it at all: a real camera is
/// not available inside a widget test.
void main() {
  Widget host(double? ratio) => MaterialApp(
    home: CameraStage(
      ratio: ratio,
      preview: const ColoredBox(
        key: ValueKey('stand-in-preview'),
        color: Colors.green,
      ),
    ),
  );

  const ratios = <double?>[null, 1.0, 3 / 4, 9 / 16];

  testWidgets('the preview element is reused across every ratio change', (
    tester,
  ) async {
    await tester.pumpWidget(host(null));

    final preview = find.byKey(const ValueKey('stand-in-preview'));
    final original = tester.element(preview);

    for (final ratio in [...ratios, null]) {
      await tester.pumpWidget(host(ratio));
      expect(
        tester.element(preview),
        same(original),
        reason: 'ratio $ratio rebuilt the preview instead of reusing it',
      );
    }
  });

  testWidgets('the framing layer stays mounted for every ratio, Full too', (
    tester,
  ) async {
    for (final ratio in ratios) {
      await tester.pumpWidget(host(ratio));
      expect(
        find.byKey(const ValueKey('framing-mask')),
        findsOneWidget,
        reason: 'ratio $ratio changed how many layers cover the preview',
      );
    }
  });

  testWidgets('the stage keeps the same number of children for every ratio', (
    tester,
  ) async {
    final counts = <int>{};
    for (final ratio in ratios) {
      await tester.pumpWidget(host(ratio));
      final stack = tester.widget<Stack>(
        find.descendant(of: find.byType(CameraStage), matching: find.byType(Stack)),
      );
      counts.add(stack.children.length);
    }
    expect(counts, hasLength(1), reason: 'layer count must not vary by ratio');
  });

  testWidgets('framing never intercepts taps meant for the viewfinder', (
    tester,
  ) async {
    await tester.pumpWidget(host(1.0));
    expect(
      tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(FramingMask),
          matching: find.byType(IgnorePointer),
        ),
      ).ignoring,
      isTrue,
    );
  });

  group('FramingMaskPainter', () {
    const size = Size(400, 800);
    Rect frameFor(double? ratio) =>
        FramingMaskPainter(ratio: ratio, scrim: Colors.black).frameRect(size);

    test('Full frames the whole screen, so nothing is dimmed', () {
      expect(frameFor(null), Offset.zero & size);
    });

    test('a square frame is centred and fits inside the screen', () {
      final frame = frameFor(1.0);
      expect(frame.width, 400);
      expect(frame.height, 400);
      expect(frame.center, Offset(size.width / 2, size.height / 2));
    });

    test('a tall frame is limited by height, not width', () {
      // 9:16 portrait inside a 1:2 screen: height-limited would overflow, so
      // the width must be the constraint.
      final frame = frameFor(9 / 16);
      expect(frame.width, 400);
      expect(frame.height, closeTo(400 * 16 / 9, 0.001));
      expect(frame.height, lessThanOrEqualTo(size.height));
    });

    test('every frame stays within the screen', () {
      for (final ratio in ratios) {
        final frame = frameFor(ratio);
        expect(frame.left, greaterThanOrEqualTo(-0.001), reason: '$ratio');
        expect(frame.top, greaterThanOrEqualTo(-0.001), reason: '$ratio');
        expect(frame.right, lessThanOrEqualTo(size.width + 0.001));
        expect(frame.bottom, lessThanOrEqualTo(size.height + 0.001));
      }
    });

    test('a degenerate ratio falls back to the full frame', () {
      // Never hand the compositor NaN or a zero-area rect: on CanvasKit that
      // is not a cosmetic problem, it can take the whole surface down.
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        expect(frameFor(bad), Offset.zero & size, reason: 'ratio $bad');
      }
    });

    test('painting a zero-sized stage is a no-op rather than a crash', () {
      final painter = FramingMaskPainter(ratio: 1.0, scrim: Colors.black);
      expect(
        () => painter.paint(Canvas(PictureRecorder()), Size.zero),
        returnsNormally,
      );
    });

    test('repaints only when the framing actually changed', () {
      const painter = FramingMaskPainter(ratio: 1.0, scrim: Colors.black);
      expect(painter.shouldRepaint(painter), isFalse);
      expect(
        painter.shouldRepaint(
          const FramingMaskPainter(ratio: null, scrim: Colors.black),
        ),
        isTrue,
      );
    });
  });

  test('every CaptureAspectRatio produces a usable frame', () {
    for (final aspect in CaptureAspectRatio.values) {
      final frame = FramingMaskPainter(
        ratio: aspect.ratio,
        scrim: Colors.black,
      ).frameRect(const Size(390, 844));
      expect(frame.width, greaterThan(0), reason: aspect.label);
      expect(frame.height, greaterThan(0), reason: aspect.label);
    }
  });
}
