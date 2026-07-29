import 'package:flutter/material.dart';

import '../models/model_option.dart';
import '../theme/app_theme.dart';

/// Selectable list of model versions.
///
/// Shows the three newest by default with the rest behind "Show all". Ten
/// radio rows is a wall of near-identical text; the newest versions are what
/// anyone actually picks, and the long tail is one tap away rather than
/// permanently in the way.
class ModelPicker extends StatefulWidget {
  final List<ModelOption> models;

  /// Currently selected `model_id`, or null to mean "the newest".
  final String? selectedModelId;

  final ValueChanged<String> onSelected;

  final bool isLoading;

  const ModelPicker({
    super.key,
    required this.models,
    required this.onSelected,
    this.selectedModelId,
    this.isLoading = false,
  });

  /// How many are shown before the list is collapsed.
  static const int collapsedCount = 3;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Open the list if the current choice is hidden inside it, so the
    // selection is never off-screen with no indication of where it went.
    final index = widget.models.indexWhere(
      (m) => m.modelId == widget.selectedModelId,
    );
    _expanded = index >= ModelPicker.collapsedCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (widget.models.isEmpty) {
      return _Notice(
        icon: Icons.cloud_off_outlined,
        text: 'Model list unavailable — using the configured default.',
      );
    }

    final selected = widget.selectedModelId ?? widget.models.first.modelId;
    final visible = _expanded
        ? widget.models
        : widget.models.take(ModelPicker.collapsedCount).toList();
    final hidden = widget.models.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ModelTile(
                  model: visible[i],
                  isSelected: visible[i].modelId == selected,
                  isNewest: i == 0 && !_expanded || visible[i] == widget.models.first,
                  onTap: () => widget.onSelected(visible[i].modelId),
                ),
              ],
            ],
          ),
        ),
        if (hidden > 0 || _expanded) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _expanded ? 'Show fewer' : 'Show all ${widget.models.length}',
              ),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One version row: name, metrics, and a check when selected.
class _ModelTile extends StatelessWidget {
  final ModelOption model;
  final bool isSelected;
  final bool isNewest;
  final VoidCallback onTap;

  const _ModelTile({
    required this.model,
    required this.isSelected,
    required this.isNewest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          model.label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? scheme.primary : null,
                          ),
                        ),
                        if (isNewest) ...[
                          const SizedBox(width: 8),
                          _Badge(text: 'Newest', color: scheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      model.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // A check reads as "this is the one" more immediately than a
              // radio dot, and keeps the row height down.
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 22,
                color: isSelected ? scheme.primary : scheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
