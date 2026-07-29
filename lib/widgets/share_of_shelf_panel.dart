import 'package:flutter/material.dart';

import '../models/share_of_shelf.dart';
import 'detection_overlay.dart' show DetectionPalette;

/// Share-of-Shelf breakdown: a proportional bar plus a per-class legend.
///
/// Colours are pulled from [DetectionPalette] so a class reads the same here as
/// it does on the bounding boxes above.
class ShareOfShelfPanel extends StatelessWidget {
  final ShareOfShelf shareOfShelf;

  const ShareOfShelfPanel({super.key, required this.shareOfShelf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (shareOfShelf.isEmpty) {
      return Text(
        'No products detected',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Share of Shelf', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              '${shareOfShelf.detectionCount} items · '
              '${shareOfShelf.classCount} '
              '${shareOfShelf.classCount == 1 ? "brand" : "brands"}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ProportionBar(shareOfShelf: shareOfShelf),
        const SizedBox(height: 12),
        // The single-line summary the brief asks for, e.g.
        // "coca_cola: 65% | pepsi: 35%".
        SelectableText(
          shareOfShelf.summaryLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...shareOfShelf.shares.map((share) => _LegendRow(share: share)),
      ],
    );
  }
}

/// A single horizontal bar split proportionally by class share.
class _ProportionBar extends StatelessWidget {
  final ShareOfShelf shareOfShelf;

  const _ProportionBar({required this.shareOfShelf});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (final share in shareOfShelf.shares)
              Expanded(
                // Integer flex, so tiny shares still occupy at least one unit
                // and never vanish entirely from the bar.
                flex: (share.fraction * 1000).round().clamp(1, 1000),
                child: ColoredBox(
                  color: DetectionPalette.forClass(share.className),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One `swatch — class — count — percentage` row beneath the bar.
class _LegendRow extends StatelessWidget {
  final ClassShare share;

  const _LegendRow({required this.share});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: DetectionPalette.forClass(share.className),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              share.className,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${share.count}×',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${share.percentage.toStringAsFixed(1)}%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
