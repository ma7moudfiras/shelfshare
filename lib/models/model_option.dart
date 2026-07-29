/// One selectable trained model version.
///
/// Only versions that actually have a trained model reach the UI -- an
/// untrained version cannot be run, so offering it would only produce errors.
class ModelOption {
  /// Value passed to the workflow's `model_id` parameter, e.g.
  /// `aystro-project/11`.
  final String modelId;

  /// Dataset version number.
  final int version;

  /// Human-readable version name from Roboflow, e.g. `2026-07-29 12:40pm`.
  final String name;

  /// Images in the version's dataset, when reported.
  final int? images;

  /// mAP@50 as a percentage, when reported.
  final double? map50;

  /// Recall as a percentage, when reported.
  final double? recall;

  const ModelOption({
    required this.modelId,
    required this.version,
    required this.name,
    this.images,
    this.map50,
    this.recall,
  });

  factory ModelOption.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) => v is num ? v.toDouble() : null;
    int? asInt(Object? v) => v is num ? v.toInt() : null;

    final version = asInt(json['version']) ?? 0;
    return ModelOption(
      modelId: json['modelId']?.toString() ?? '',
      version: version,
      name: json['name']?.toString() ?? 'Version $version',
      images: asInt(json['images']),
      map50: asDouble(json['map50']),
      recall: asDouble(json['recall']),
    );
  }

  /// Primary label in the picker, e.g. `Version 11`.
  String get label => 'Version $version';

  /// Secondary line: what distinguishes this version from the others.
  ///
  /// Metrics are shown when Roboflow reports them, since choosing a model is
  /// mostly a question of which one performs better.
  String get subtitle {
    final parts = <String>[
      if (images != null) '$images images',
      if (map50 != null) 'mAP ${map50!.toStringAsFixed(0)}%',
      if (recall != null) 'recall ${recall!.toStringAsFixed(0)}%',
    ];
    return parts.isEmpty ? name : parts.join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is ModelOption && other.modelId == modelId;

  @override
  int get hashCode => modelId.hashCode;

  @override
  String toString() => 'ModelOption($modelId)';
}

/// The set of models and classes the project offers.
class ModelCatalog {
  final List<ModelOption> models;

  /// Every class the project knows about, whether or not it appears in a
  /// particular capture.
  final List<String> classes;

  const ModelCatalog({required this.models, required this.classes});

  const ModelCatalog.empty() : models = const [], classes = const [];

  bool get isEmpty => models.isEmpty && classes.isEmpty;

  factory ModelCatalog.fromJson(Map<String, dynamic> json) {
    final models = <ModelOption>[];
    final rawModels = json['models'];
    if (rawModels is List) {
      for (final entry in rawModels) {
        if (entry is Map) {
          final option = ModelOption.fromJson(entry.cast<String, dynamic>());
          if (option.modelId.isNotEmpty) models.add(option);
        }
      }
    }

    final classes = <String>[];
    final rawClasses = json['classes'];
    if (rawClasses is List) {
      for (final entry in rawClasses) {
        final name = entry?.toString();
        if (name != null && name.isNotEmpty) classes.add(name);
      }
    }

    return ModelCatalog(models: models, classes: classes);
  }
}
