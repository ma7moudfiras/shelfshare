import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'screens/capture_screen.dart';
import 'theme/app_theme.dart';
import 'services/detection_service.dart';
import 'services/roboflow_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads `.env`. Tolerates a missing file so the app still starts and can
  // explain what is missing, rather than crashing on launch.
  await AppConfig.load();

  runApp(const ShelfMonitorApp());
}

class ShelfMonitorApp extends StatefulWidget {
  const ShelfMonitorApp({super.key});

  @override
  State<ShelfMonitorApp> createState() => _ShelfMonitorAppState();
}

class _ShelfMonitorAppState extends State<ShelfMonitorApp> {
  DetectionService? _detectionService;

  @override
  void initState() {
    super.initState();
    // Built only when an API key is present; the capture screen falls back to
    // capture-only behaviour when this is null.
    if (AppConfig.isConfigured) {
      _detectionService = RoboflowService();
    }
  }

  @override
  void dispose() {
    _detectionService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // The capture screen is a viewfinder: it is dark regardless of the
      // system setting, and the rest of the chrome should match it.
      themeMode: ThemeMode.dark,
      home: CaptureScreen(detectionService: _detectionService),
    );
  }
}
