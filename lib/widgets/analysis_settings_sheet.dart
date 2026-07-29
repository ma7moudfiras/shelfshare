import 'package:flutter/material.dart';

import '../models/model_option.dart';
import 'detection_overlay.dart' show DetectionPalette;

/// Choices made in the settings sheet.
class AnalysisSettings {
  /// `model_id` to run, or null to use the configured default.
  final String? modelId;

  /// Classes to keep. Empty means all products.
  final Set<String> selectedClasses;

  const AnalysisSettings({this.modelId, this.selectedClasses = const {}});

  bool get showsAllProducts => selectedClasses.isEmpty;

  AnalysisSettings copyWith({
    String? modelId,
    Set<String>? selectedClasses,
    bool clearModel = false,
  }) {
    return AnalysisSettings(
      modelId: clearModel ? null : (modelId ?? this.modelId),
      selectedClasses: selectedClasses ?? this.selectedClasses,
    );
  }
}

/// Bottom sheet for choosing the model version and which products to count.
///
/// Both choices matter to the numbers on screen: the model decides what gets
/// detected at all, and the class filter decides what Share of Shelf is a share
/// *of*, so they belong together rather than buried in separate menus.
class AnalysisSettingsSheet extends StatefulWidget {
  /// Model versions offered. Empty when the catalog could not be loaded.
  final List<ModelOption> models;

  /// Every class the project knows about.
  final List<String> availableClasses;

  final AnalysisSettings initial;

  /// True while the catalog is still being fetched.
  final bool isLoadingCatalog;

  const AnalysisSettingsSheet({
    super.key,
    required this.models,
    required this.availableClasses,
    required this.initial,
    this.isLoadingCatalog = false,
  });

  @override
  State<AnalysisSettingsSheet> createState() => _AnalysisSettingsSheetState();
}

class _AnalysisSettingsSheetState extends State<AnalysisSettingsSheet> {
  late AnalysisSettings _settings = widget.initial;

  void _selectModel(String? modelId) {
    setState(() => _settings = _settings.copyWith(modelId: modelId));
  }

  void _toggleClass(String className, bool selected) {
    final next = Set<String>.from(_settings.selectedClasses);
    if (selected) {
      next.add(className);
    } else {
      next.remove(className);
    }
    setState(() => _settings = _settings.copyWith(selectedClasses: next));
  }

  /// Clearing the selection is what "All products" means -- an explicit list of
  /// every class would silently stop including classes added later.
  void _selectAllProducts() {
    setState(() => _settings = _settings.copyWith(selectedClasses: const {}));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Analysis settings', style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),

              Text('Model version', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Newer versions are trained on more images and usually detect '
                'more product types.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _buildModelPicker(theme),

              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Products', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  if (!_settings.showsAllProducts)
                    TextButton(
                      onPressed: _selectAllProducts,
                      child: const Text('All products'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _settings.showsAllProducts
                    ? 'Counting every detected product.'
                    : 'Share of Shelf is calculated across the selected '
                          'products only.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _buildClassChips(theme),

              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_settings),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelPicker(ThemeData theme) {
    if (widget.isLoadingCatalog) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (widget.models.isEmpty) {
      return Text(
        'Model list unavailable — using the configured default.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return RadioGroup<String>(
      groupValue: _settings.modelId ?? widget.models.first.modelId,
      onChanged: _selectModel,
      child: Column(
        children: [
          for (final model in widget.models)
            RadioListTile<String>(
              value: model.modelId,
              title: Text(model.label),
              subtitle: Text(model.subtitle),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildClassChips(ThemeData theme) {
    if (widget.availableClasses.isEmpty) {
      return Text(
        'Product list unavailable — all detections are counted.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All products'),
          selected: _settings.showsAllProducts,
          onSelected: (_) => _selectAllProducts(),
        ),
        for (final className in widget.availableClasses)
          FilterChip(
            label: Text(className),
            selected: _settings.selectedClasses.contains(className),
            avatar: CircleAvatar(
              backgroundColor: DetectionPalette.forClass(className),
              radius: 7,
            ),
            onSelected: (selected) => _toggleClass(className, selected),
          ),
      ],
    );
  }
}
