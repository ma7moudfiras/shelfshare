import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_gate.dart';
import 'screens/backend_missing_screen.dart';
import 'services/auth_service.dart';
import 'services/detection_service.dart';
import 'services/roboflow_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads `.env`. Tolerates a missing file so the app still starts and can
  // explain what is missing, rather than crashing on launch.
  await AppConfig.load();

  // Skipped when unconfigured so the app can still start and say so. It will
  // not run without a backend -- see [ShelfMonitorApp.build].
  var backend = BackendStatus.notConfigured;
  if (AppConfig.hasSupabase) {
    backend = await _initialiseBackend();
  }

  runApp(ShelfMonitorApp(backend: backend));
}

/// How far the backend got at startup.
enum BackendStatus {
  /// The build carries no Supabase credentials at all.
  notConfigured,

  /// Credentials are present but the server could not be reached.
  unreachable,

  /// Ready to use.
  ready,
}

/// Brings Supabase up without letting it hold the app hostage.
///
/// This is awaited before the first frame, so anything slow here is a blank
/// screen with nothing on it -- and a rep standing inside a shop is exactly the
/// person most likely to have a connection bad enough to cause that. Failing
/// after a bounded wait means they get a screen that explains itself and offers
/// a retry, instead of staring at nothing.
Future<BackendStatus> _initialiseBackend() async {
  if (_isSupabaseLive) return BackendStatus.ready;

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl!,
      publishableKey: AppConfig.supabasePublishableKey!,
    ).timeout(const Duration(seconds: 10));
    return BackendStatus.ready;
  } catch (error) {
    // Deliberately broad: a timeout, a DNS failure and a TLS error all mean the
    // same thing to the person holding the phone.
    debugPrint('Supabase could not be reached at startup: $error');
    // A call that timed out may still have finished afterwards, and a retry
    // reports the client already exists. Both are success.
    return _isSupabaseLive ? BackendStatus.ready : BackendStatus.unreachable;
  }
}

/// Whether the Supabase client exists and can be touched.
///
/// [Supabase.instance] throws before initialisation, so asking is the only way
/// to find out; there is no flag to read.
bool get _isSupabaseLive {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}

class ShelfMonitorApp extends StatefulWidget {
  final BackendStatus backend;

  const ShelfMonitorApp({super.key, required this.backend});

  @override
  State<ShelfMonitorApp> createState() => _ShelfMonitorAppState();
}

class _ShelfMonitorAppState extends State<ShelfMonitorApp> {
  DetectionService? _detectionService;
  AuthService? _authService;
  late BackendStatus _backend = widget.backend;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    // Built only when an API key is present; the capture screen falls back to
    // capture-only behaviour when this is null.
    if (AppConfig.isConfigured) _detectionService = RoboflowService();
    _attachAuthService();
  }

  /// Only safe once `Supabase.initialize` has succeeded: the client throws if
  /// it is touched before that.
  void _attachAuthService() {
    if (_backend == BackendStatus.ready && _authService == null) {
      _authService = SupabaseAuthService();
    }
  }

  Future<void> _retryBackend() async {
    setState(() => _isRetrying = true);
    final status = await _initialiseBackend();
    if (!mounted) return;
    setState(() {
      _backend = status;
      _isRetrying = false;
      _attachAuthService();
    });
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
      // No auth service means no sign-in, and this app is not open to
      // whoever finds the URL. It used to fall through to the capture screen
      // here, which quietly turned a missing environment variable into a
      // public deployment with no login and a live inference budget behind it.
      // A configuration gap must look like one.
      home: authService == null
          ? BackendMissingScreen(
              status: _backend,
              onRetry: _isRetrying ? null : _retryBackend,
            )
          : AuthGate(
              authService: authService,
              detectionService: _detectionService,
            ),
    );
  }
}
