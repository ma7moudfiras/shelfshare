import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/model_option.dart';

/// Fetches the list of runnable model versions and the project's classes.
///
/// On web this hits the same-origin `/api/models` proxy, so no Roboflow key is
/// needed in the browser. On mobile it queries the Roboflow API directly with
/// the key from `.env`.
///
/// Failure is never fatal: the picker falls back to whatever model is already
/// configured, so losing the catalog degrades the UI rather than the app.
class ModelCatalogService {
  final http.Client _client;
  final bool _ownsClient;

  /// Where to fetch the catalog from. Defaults to the mode [AppConfig] selects.
  final Uri endpoint;

  final Duration timeout;

  ModelCatalogService({
    http.Client? client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       endpoint = endpoint ?? _defaultEndpoint();

  static Uri _defaultEndpoint() {
    if (AppConfig.usesProxy) {
      // Sits alongside /api/detect, so derive it from the detection endpoint
      // rather than assuming an origin.
      final detect = AppConfig.detectionEndpoint;
      return detect.replace(
        path: detect.path.replaceFirst(RegExp(r'detect/?$'), 'models'),
      );
    }
    // The detector's own project, not the workflow -- a workflow document id
    // is not a project slug this endpoint can list /versions for.
    return Uri.parse(
      'https://api.roboflow.com/${AppConfig.workspace}/${AppConfig.detectProject}',
    );
  }

  /// Returns the catalog, or an empty one when it cannot be retrieved.
  Future<ModelCatalog> fetchCatalog() async {
    try {
      final uri = AppConfig.usesProxy
          ? endpoint
          : endpoint.replace(
              queryParameters: {'api_key': AppConfig.roboflowApiKey},
            );

      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return const ModelCatalog.empty();

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const ModelCatalog.empty();
      final json = decoded.cast<String, dynamic>();

      // The proxy returns a normalised shape; a direct Roboflow call returns
      // the raw project document, which needs converting here.
      if (json.containsKey('models')) return ModelCatalog.fromJson(json);
      return _fromRoboflowProject(json);
    } catch (_) {
      // Catalog is a convenience -- never let it break the capture flow.
      return const ModelCatalog.empty();
    }
  }

  /// Converts the raw Roboflow project document used by the direct path.
  ModelCatalog _fromRoboflowProject(Map<String, dynamic> json) {
    final models = <ModelOption>[];

    final versions = json['versions'];
    if (versions is List) {
      for (final entry in versions) {
        if (entry is! Map) continue;
        final version = entry.cast<String, dynamic>();

        final model = version['model'];
        final hasModel = model != null && (model is! List || model.isNotEmpty);
        if (!hasModel) continue;

        final number = int.tryParse(
          version['id']?.toString().split('/').last ?? '',
        );
        if (number == null) continue;

        final metrics = (model is List ? model.first : model);
        double? metric(String key) {
          if (metrics is! Map) return null;
          final value = metrics[key];
          return value is num ? value.toDouble() : null;
        }

        models.add(
          ModelOption(
            modelId: '${AppConfig.detectProject}/$number',
            version: number,
            name: version['name']?.toString() ?? 'Version $number',
            images: (version['images'] as num?)?.toInt(),
            map50: metric('map') ?? metric('map50'),
            recall: metric('recall'),
          ),
        );
      }
    }

    models.sort((a, b) => b.version.compareTo(a.version));

    final classes = <String>[];
    final project = json['project'];
    if (project is Map && project['classes'] is Map) {
      classes.addAll((project['classes'] as Map).keys.map((k) => k.toString()));
      classes.sort();
    }

    return ModelCatalog(models: models, classes: classes);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
