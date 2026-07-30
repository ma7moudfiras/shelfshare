import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/detection_exception.dart';

/// Typed access to the values in `.env`.
///
/// Every secret lives here and nowhere else -- no key is ever hard-coded, and
/// nothing outside this class reads [dotenv] directly.
///
/// ## Two deployment modes
///
/// **Direct (mobile).** The app holds the Roboflow API key and calls the
/// serverless endpoint itself.
///
/// **Proxied (web).** Anything bundled into a web build is readable by anyone
/// who opens developer tools, so a private API key must never be shipped there.
/// On web the app instead posts to a same-origin proxy (a Vercel serverless
/// function) that holds the key server-side and forwards the request.
/// [usesProxy] decides which mode is active.
class AppConfig {
  const AppConfig._();

  static const _envFileName = '.env';

  /// Proxy path used on web when `ROBOFLOW_PROXY_URL` is not set explicitly.
  static const defaultProxyPath = '/api/detect';

  /// Loads `.env` from the bundled assets.
  ///
  /// Tolerates a missing file so the app can still start and show a clear
  /// configuration error in the UI, rather than crashing on launch.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: _envFileName);
    } catch (_) {
      // Leaves dotenv empty; [isConfigured] reports false and the capture
      // screen surfaces the setup instructions.
    }
  }

  static String? _read(String key) {
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) return null;
    // Guard against the placeholder from .env.example being left in place.
    if (value.startsWith('your_') || value == 'changeme') return null;
    return value;
  }

  /// Roboflow private API key, from `app.roboflow.com/settings/api`.
  ///
  /// Only read in direct mode. Throws [DetectionConfigException] rather than
  /// returning null so a missing key fails loudly at the call site instead of
  /// producing a 401 later.
  static String get roboflowApiKey {
    final key = _read('ROBOFLOW_API_KEY');
    if (key == null) {
      throw const DetectionConfigException(
        'ROBOFLOW_API_KEY is not set. Copy .env.example to .env and add your '
        'Roboflow API key from https://app.roboflow.com/settings/api',
      );
    }
    return key;
  }

  /// Workspace slug that owns the workflow.
  static String get workspace =>
      _read('ROBOFLOW_WORKSPACE') ?? 'ma7mouds-workspace';

  /// Workflow slug (not the workflow document id).
  static String get workflowId =>
      _read('ROBOFLOW_WORKFLOW_ID') ?? 'aystro-project';

  /// Inference host base URL.
  static String get baseUrl =>
      _read('ROBOFLOW_BASE_URL') ?? 'https://serverless.roboflow.com';

  /// Model version run by the workflow, as `<project>/<version>`.
  ///
  /// The workflow itself defaults to `aystro-project/1`, which was trained on
  /// 27 images before most classes existed and therefore only reliably finds
  /// `coca-cola`. Pointing at the newest trained version is what makes the
  /// other products show up.
  ///
  /// Set `ROBOFLOW_MODEL_ID` in `.env` to pin a different version. On a web
  /// deployment the server-side `ROBOFLOW_MODEL_ID` takes precedence, so the
  /// model can be switched from the Vercel dashboard without rebuilding.
  static String get modelId => _read('ROBOFLOW_MODEL_ID') ?? defaultModelId;

  /// Newest trained version of the `aystro-project` model.
  static const defaultModelId = 'aystro-project/11';

  /// Explicit proxy URL, when set. Overrides the web default and lets a mobile
  /// build be pointed at the same proxy.
  static String? get proxyUrl => _read('ROBOFLOW_PROXY_URL');

  /// Whether requests go through the server-side proxy instead of straight to
  /// Roboflow.
  ///
  /// Always true on web: a browser build must never carry the private key.
  static bool get usesProxy => kIsWeb || proxyUrl != null;

  /// The URL the app should POST to, given the active mode.
  static Uri get detectionEndpoint {
    if (usesProxy) return Uri.parse(proxyUrl ?? defaultProxyPath);
    return workflowEndpoint;
  }

  /// Direct Roboflow workflow endpoint, bypassing any proxy.
  static Uri get workflowEndpoint =>
      Uri.parse('$baseUrl/$workspace/workflows/$workflowId');

  // --- Supabase -------------------------------------------------------------

  /// Supabase project URL.
  static String? get supabaseUrl => _read('SUPABASE_URL');

  /// Publishable (anon) key.
  ///
  /// Safe in a client build by design: it grants nothing on its own, because
  /// every table is protected by Row Level Security. This is NOT the
  /// service_role key, which bypasses RLS and must never ship to a device.
  static String? get supabasePublishableKey =>
      _read('SUPABASE_PUBLISHABLE_KEY') ?? _read('SUPABASE_ANON_KEY');

  /// Whether the backend is configured. When false the app runs in its
  /// original single-user capture mode rather than failing to start.
  static bool get hasSupabase =>
      supabaseUrl != null && supabasePublishableKey != null;

  /// Whether the app has what it needs to run detection.
  ///
  /// In proxy mode the client needs no key at all -- the server holds it -- so
  /// only direct mode requires `ROBOFLOW_API_KEY`.
  static bool get isConfigured =>
      usesProxy || _read('ROBOFLOW_API_KEY') != null;
}
