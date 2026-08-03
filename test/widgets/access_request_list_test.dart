import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/user_profile.dart';
import 'package:shelf_monitor/theme/app_theme.dart';
import 'package:shelf_monitor/widgets/access_request_list.dart';

/// Pumps the list inside the real app theme.
///
/// Using [AppTheme] rather than a bare [MaterialApp] is the entire point of
/// these tests: the defect they exist to catch lived in the theme, not in the
/// widget, and a default-themed harness would have shown a perfectly healthy
/// button.
Future<List<FlutterErrorDetails>> _pumpList(
  WidgetTester tester, {
  required Size size,
  bool isBusy = false,
  void Function(UserProfile, UserRole)? onApprove,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: AccessRequestList(
          requests: const [
            UserProfile(
              id: 'u1',
              role: UserRole.pending,
              fullName: 'Sara Qasim',
              email: 'sara@example.com',
              requestedCompanyId: 'c1',
              requestedCompanyName: 'UniPal',
            ),
          ],
          isBusy: isBusy,
          showCompany: true,
          onApprove: onApprove ?? (_, _) {},
          onDecline: (_) {},
        ),
      ),
    ),
  );

  FlutterError.onError = previous;
  return errors;
}

void main() {
  group('AccessRequestList', () {
    // The regression this file was written for. A minimum size of
    // `Size.fromHeight(48)` is a minimum *width* of infinity, which a Row lays
    // out with an unbounded main axis and cannot satisfy. The button failed
    // layout and was never painted, so an admin saw Decline on its own with no
    // way to approve anybody -- and no error, because release builds do not
    // draw the overflow stripes.
    testWidgets('shows both actions on a narrow phone', (tester) async {
      final errors = await _pumpList(tester, size: const Size(360, 780));

      expect(
        errors,
        isEmpty,
        reason: 'laying out the tile must not produce layout errors',
      );
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      final approve = tester.getRect(find.text('Approve'));
      expect(approve.width, greaterThan(0));
      expect(
        approve.right,
        lessThanOrEqualTo(360),
        reason: 'Approve must sit inside the viewport, not past its edge',
      );
    });

    testWidgets('shows both actions on a desktop window', (tester) async {
      final errors = await _pumpList(tester, size: const Size(1440, 900));

      expect(errors, isEmpty);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('approving offers a role rather than assuming one', (
      tester,
    ) async {
      final granted = <UserRole>[];
      await _pumpList(
        tester,
        size: const Size(390, 844),
        onApprove: (_, role) => granted.add(role),
      );

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Approve as sales representative'), findsOneWidget);
      expect(find.text('Approve as company admin'), findsOneWidget);

      await tester.tap(find.text('Approve as sales representative'));
      await tester.pumpAndSettle();

      expect(granted, [UserRole.salesRep]);
    });

    testWidgets('both actions are disabled while an action is running', (
      tester,
    ) async {
      await _pumpList(tester, size: const Size(390, 844), isBusy: true);

      final approve = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Approve'),
      );
      final decline = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Decline'),
      );

      expect(approve.onPressed, isNull);
      expect(decline.onPressed, isNull);
    });

    testWidgets('declining asks first', (tester) async {
      await _pumpList(tester, size: const Size(390, 844));

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(find.text('Decline this request?'), findsOneWidget);
    });
  });
}
