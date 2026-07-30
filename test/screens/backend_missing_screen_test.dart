import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/screens/backend_missing_screen.dart';
import 'package:shelf_monitor/screens/capture_screen.dart';

/// A build with no Supabase credentials used to fall through to the capture
/// screen. That turned a missing environment variable into a public deployment
/// with no sign-in and a live Roboflow budget behind it -- which is how the
/// deployed app ended up opening straight onto the camera.
///
/// The dead end is the feature. These tests exist so it stays one.
void main() {
  testWidgets('names the variables an operator has to set', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BackendMissingScreen()));

    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('SUPABASE_PUBLISHABLE_KEY'), findsOneWidget);
  });

  testWidgets('says the app will not start, and why', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BackendMissingScreen()));

    expect(find.textContaining('no backend'), findsOneWidget);
    expect(find.textContaining('cannot sign anyone in'), findsOneWidget);
  });

  testWidgets('offers no way through to the app', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BackendMissingScreen()));

    expect(find.byType(CaptureScreen), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
      findsNothing,
      reason: 'an unconfigured build must not offer a route into the app',
    );
  });
}
