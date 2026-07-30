import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/main.dart' show BackendStatus;
import 'package:shelf_monitor/screens/backend_missing_screen.dart';
import 'package:shelf_monitor/screens/capture_screen.dart';

/// A build with no Supabase credentials used to fall through to the capture
/// screen. That turned a missing environment variable into a public deployment
/// with no sign-in and a live Roboflow budget behind it -- which is how the
/// deployed app ended up opening straight onto the camera.
///
/// The dead end is the feature. These tests exist so it stays one.
void main() {
  Widget host(BackendStatus status, {VoidCallback? onRetry}) => MaterialApp(
    home: BackendMissingScreen(status: status, onRetry: onRetry),
  );

  group('not configured', () {
    testWidgets('names the variables an operator has to set', (tester) async {
      await tester.pumpWidget(host(BackendStatus.notConfigured));

      expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
      expect(find.textContaining('SUPABASE_PUBLISHABLE_KEY'), findsOneWidget);
    });

    testWidgets('says the app will not start, and why', (tester) async {
      await tester.pumpWidget(host(BackendStatus.notConfigured));

      expect(find.textContaining('no backend'), findsOneWidget);
      expect(find.textContaining('cannot sign anyone in'), findsOneWidget);
    });

    testWidgets('offers no way through to the app', (tester) async {
      await tester.pumpWidget(host(BackendStatus.notConfigured));

      expect(find.byType(CaptureScreen), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsNothing,
        reason: 'an unconfigured build must not offer a route into the app',
      );
    });
  });

  group('unreachable', () {
    // Distinct from a misconfigured build on purpose. This one is usually just
    // signal, and blaming the deployment would send a rep to the wrong person.
    testWidgets('blames the connection, not the deployment', (tester) async {
      await tester.pumpWidget(host(BackendStatus.unreachable));

      expect(find.textContaining('Cannot reach the server'), findsOneWidget);
      expect(find.textContaining('signal'), findsOneWidget);
      expect(find.textContaining('SUPABASE_URL'), findsNothing);
    });

    testWidgets('offers a retry that actually fires', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        host(BackendStatus.unreachable, onRetry: () => retries++),
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('the retry is disabled while one is already running', (
      tester,
    ) async {
      await tester.pumpWidget(host(BackendStatus.unreachable));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}
