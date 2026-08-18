import 'package:flutter/material.dart';

import '../models/share_of_shelf.dart';
import 'detection_overlay.dart' show DetectionPalette;

/// Share-of-Shelf breakdown: a proportional bar, then one heading per brand
/// (its total share of the shelf) with that brand's variants listed beneath
/// it, each shown as a share of *its own brand* rather than of the shelf.
///
/// Colours are pulled from [DetectionPalette] so a class reads the same here as
/// it does on the bounding boxes above.
class ShareOfShelfPanel extends StatelessWidget {
  final ShareOfShelf shareOfShelf;

  const ShareOfShelfPanel({super.key, required this.shareOfShelf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = shareOfShelf.groupedByBrand;

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
        // Both halves flex: with a fixed title and a Spacer, a wide count
        // ("128 items · 6 brands") pushed the row past the edge on a narrow
        // phone, and an overflowing row clips rather than wraps.
        Row(
          children: [
            Flexible(
              child: Text(
                'Share of Shelf',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 12),
            // Tight, so the count stays flush right instead of shrink-wrapping
            // against the title.
            Expanded(
              child: Text(
                '${shareOfShelf.detectionCount} items · '
                '${groups.length} '
                '${groups.length == 1 ? "brand" : "brands"}',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ProportionBar(shareOfShelf: shareOfShelf),
        const SizedBox(height: 16),
        for (final group in groups) _BrandGroupSection(group: group),
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

/// One brand's heading -- swatch, name, and its total share of the whole
/// shelf -- followed by its variant rows indented beneath it.
class _BrandGroupSection extends StatelessWidget {
  final BrandGroup group;

  const _BrandGroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: DetectionPalette.forClass(group.brand),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.brand,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${group.percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          for (final variant in group.variants)
            _VariantRow(variant: variant, brandFraction: group.fraction),
        ],
      ),
    );
  }
}

/// One variant row indented under its brand heading. The percentage shown
/// here is the variant's share *of that brand* (so a brand's rows sum to
/// 100%), not of the whole shelf -- the heading above already covers that.
class _VariantRow extends StatelessWidget {
  final ClassShare variant;
  final double brandFraction;

  const _VariantRow({required this.variant, required this.brandFraction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // brandFraction is always positive here: a variant only exists inside a
    // group whose fraction is the sum of its variants' own positive shares.
    final shareOfBrand = variant.fraction / brandFraction * 100;

    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 3, bottom: 3),
      child: Row(
        children: [
          Text(
            '•  ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              variant.className,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${variant.count}×',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${shareOfBrand.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
