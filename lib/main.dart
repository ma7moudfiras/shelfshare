import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_gate.dart';
import 'screens/capture_screen.dart';
import 'services/auth_service.dart';
import 'services/detection_service.dart';
import 'services/roboflow_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads `.env`. Tolerates a missing file so the app still starts and can
  // explain what is missing, rather than crashing on launch.
  await AppConfig.load();

  // Optional on purpose: without Supabase the app still runs as the original
  // single-user capture tool, which keeps it usable while the backend is being
  // set up rather than turning a config gap into a blank screen.
  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl!,
      publishableKey: AppConfig.supabasePublishableKey!,
    );
  }

  runApp(const ShelfMonitorApp());
}

class ShelfMonitorApp extends StatefulWidget {
  const ShelfMonitorApp({super.key});

  @override
  State<ShelfMonitorApp> createState() => _ShelfMonitorAppState();
}

class _ShelfMonitorAppState extends State<ShelfMonitorApp> {
  DetectionService? _detectionService;
  AuthService? _authService;

  @override
  void initState() {
    super.initState();
    // Built only when an API key is present; the capture screen falls back to
    // capture-only behaviour when this is null.
    if (AppConfig.isConfigured) _detectionService = RoboflowService();
    if (AppConfig.hasSupabase) _authService = SupabaseAuthService();
  }

  @override
  void dispose() {
    _detectionService?.dispose();
    _authService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = _authService;

    return MaterialApp(
      title: 'Shelf Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: authService == null
          ? CaptureScreen(detectionService: _detectionService)
          : AuthGate(
              authService: authService,
              detectionService: _detectionService,
            ),
    );
  }
}
