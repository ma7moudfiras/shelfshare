import 'package:flutter/material.dart';

import '../models/model_option.dart';
import '../theme/app_theme.dart';
import 'detection_overlay.dart' show DetectionPalette;
import 'model_picker.dart';

/// Choices made in the settings sheet.
class AnalysisSettings {
  /// `model_id` to run, or null to use the configured default.
  final String? modelId;

  /// Classes to keep. Empty means all products.
  final Set<String> selectedClasses;

  /// Minimum score a detection must reach, 0.0 - 1.0.
  ///
  /// Exposing this is what lets a shelf with several products stop reporting
  /// only the strongest one.
  final double confidence;

  const AnalysisSettings({
    this.modelId,
    this.selectedClasses = const {},
    this.confidence = defaultConfidence,
  });

  /// Matches the workflow's own default (`detect_confidence` input).
  ///
  /// Was 0.7, deliberately stricter, to keep phantom detections out of
  /// customer-facing counts. Lowered during active data-collection: a rep
  /// correcting detections needs to actually see the weaker ones (a class
  /// with few training images often scores under 0.7) rather than have them
  /// hidden before there's a chance to fix and re-upload them. Revisit this
  /// once the variant classifiers have enough corrected data that raising it
  /// back stops hiding real signal.
  static const double defaultConfidence = 0.4;

  bool get showsAllProducts => selectedClasses.isEmpty;

  AnalysisSettings copyWith({
    String? modelId,
    Set<String>? selectedClasses,
    double? confidence,
    bool clearModel = false,
  }) {
    return AnalysisSettings(
      modelId: clearModel ? null : (modelId ?? this.modelId),
      selectedClasses: selectedClasses ?? this.selectedClasses,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Bottom sheet for choosing the model, threshold and which products to count.
///
/// All three change the numbers on screen, so they belong in one place rather
/// than scattered across separate menus.
class AnalysisSettingsSheet extends StatefulWidget {
  final List<ModelOption> models;
  final List<String> availableClasses;
  final AnalysisSettings initial;
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

  void _toggleClass(String className, bool selected) {
    final next = Set<String>.from(_settings.selectedClasses);
    selected ? next.add(className) : next.remove(className);
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

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                children: [
                  Text(
                    'Analysis settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                children: [
                  _SectionHeader(
                    title: 'Model version',
                    subtitle:
                        'Newer versions train on more images. Metrics '
                        'are mAP@50 — Roboflow’s dashboard headlines the '
                        'stricter mAP50-95, so numbers there read lower.',
                  ),
                  const SizedBox(height: 12),
                  ModelPicker(
                    models: widget.models,
                    selectedModelId: _settings.modelId,
                    isLoading: widget.isLoadingCatalog,
                    onSelected: (id) => setState(
                      () => _settings = _settings.copyWith(modelId: id),
                    ),
                  ),

                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: 'Minimum confidence',
                    trailing: '${(_settings.confidence * 100).round()}%',
                    subtitle:
                        'Lower this to reveal products the model is less '
                        'sure about. Classes with fewer training images often '
                        'score below the default '
                        '${(AnalysisSettings.defaultConfidence * 100).round()}%.',
                  ),
                  Slider(
                    value: _settings.confidence,
                    min: 0.05,
                    max: 0.9,
                    divisions: 17,
                    label: '${(_settings.confidence * 100).round()}%',
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(confidence: v),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Products',
                    subtitle: _settings.showsAllProducts
                        ? 'Counting every detected product.'
                        : 'Share of Shelf is calculated across the selected '
                              'products only.',
                  ),
                  const SizedBox(height: 12),
                  _buildClassChips(theme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                // Full width is stated here rather than inherited from the
                // button theme, which only sets a height floor.
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_settings),
                    child: const Text('Apply'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
        // Colours come from the chip theme, which gives selected and unselected
        // chips genuinely different fills and foregrounds. The translucent
        // overrides that used to live here landed a few points away from the
        // dark background and were close to unreadable.
        FilterChip(
          label: const Text('All products'),
          selected: _settings.showsAllProducts,
          onSelected: (_) => _selectAllProducts(),
        ),
        for (final className in widget.availableClasses)
          FilterChip(
            label: Text(className),
            selected: _settings.selectedClasses.contains(className),
            avatar: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: DetectionPalette.forClass(className),
                shape: BoxShape.circle,
              ),
            ),
            onSelected: (s) => _toggleClass(className, s),
          ),
      ],
    );
  }
}

/// Consistent section title, optional trailing value, and explanatory line.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  trailing!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
