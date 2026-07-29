import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/detection_exception.dart';

/// Typed access to the values in `.env`.
///
/// Every secret lives here and nowhere else -- no key is ever hard-coded, and
/// nothing outside this class reads [dotenv] directly.
class AppConfig {
  const AppConfig._();

  static const _envFileName = '.env';

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
  /// Throws [DetectionConfigException] rather than returning null so a missing
  /// key fails loudly at the call site instead of producing a 401 later.
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

  /// Full POST endpoint for running the workflow.
  static Uri get workflowEndpoint =>
      Uri.parse('$baseUrl/$workspace/workflows/$workflowId');

  /// Whether an API key is present. The UI checks this before offering capture.
  static bool get isConfigured => _read('ROBOFLOW_API_KEY') != null;
}
