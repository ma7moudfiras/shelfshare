import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/theme/layout.dart';

void main() {
  group('size classes follow window width, not device', () {
    test('a narrow window is compact wherever it is running', () {
      expect(Breakpoints.sizeFor(320), LayoutSize.compact);
      expect(Breakpoints.sizeFor(639), LayoutSize.compact);
    });

    test('a tablet-width window uses a rail', () {
      expect(Breakpoints.sizeFor(640), LayoutSize.medium);
      expect(Breakpoints.sizeFor(1023), LayoutSize.medium);
      expect(LayoutSize.medium.usesRail, isTrue);
      expect(LayoutSize.medium.isWide, isFalse);
    });

    test('a laptop window is expanded', () {
      expect(Breakpoints.sizeFor(1024), LayoutSize.expanded);
      expect(Breakpoints.sizeFor(2560), LayoutSize.expanded);
      expect(LayoutSize.expanded.isWide, isTrue);
    });

    test('compact is the only size that keeps navigation at the bottom', () {
      expect(LayoutSize.compact.usesRail, isFalse);
    });
  });

  group('ContentShell', () {
    testWidgets('fills a narrow window but not a wide one', (tester) async {
      Future<double> widthAt(double windowWidth) async {
        tester.view.physicalSize = Size(windowWidth, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ContentShell(
                maxWidth: 720,
                child: SizedBox.expand(key: ValueKey('content')),
              ),
            ),
          ),
        );
        return tester.getSize(find.byKey(const ValueKey('content'))).width;
      }

      expect(await widthAt(400), 400);
      // Held to a readable measure rather than stretched across the monitor.
      expect(await widthAt(1600), 720);
    });

    // The regression this exists for: Align expands to its constraints given
    // the chance. In a bottomNavigationBar that means claiming the whole window
    // and collapsing the page above it to zero height -- which is exactly what
    // happened to the review screen's photo and editor panel.
    testWidgets('shrinkWrapHeight leaves the page its height', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColoredBox(
              color: Colors.blue,
              child: SizedBox.expand(key: ValueKey('page')),
            ),
            bottomNavigationBar: ContentShell(
              maxWidth: 720,
              shrinkWrapHeight: true,
              child: SizedBox(height: 60, key: ValueKey('bar')),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const ValueKey('bar'))).height, 60);
      expect(
        tester.getSize(find.byKey(const ValueKey('page'))).height,
        greaterThan(700),
        reason: 'the bottom bar must not swallow the page',
      );
    });
  });
}
