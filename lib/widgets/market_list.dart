import 'package:flutter/material.dart';

import '../models/point_of_sale.dart';
import '../theme/layout.dart';
import 'empty_state.dart';

/// The markets a company sells into.
///
/// On a wide window these become a grid: a market is a small, self-contained
/// card, and stretching each one across a monitor wastes the space without
/// making anything easier to read.
class MarketList extends StatelessWidget {
  /// Null while loading.
  final List<PointOfSale>? markets;

  final ValueChanged<PointOfSale> onOpen;

  const MarketList({super.key, required this.markets, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final items = markets;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No markets yet',
        message:
            'Add the supermarkets and shops your team visits. Each one holds '
            'the fridges your reps photograph.',
      );
    }

    final columns = switch (context.layoutSize) {
      LayoutSize.expanded => 3,
      LayoutSize.medium => 2,
      LayoutSize.compact => 1,
    };

    return ContentShell(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // Tall enough for a name, a location and the fridge line without the
          // card growing a scrollbar on a narrow phone.
          mainAxisExtent: 132,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) =>
            _MarketCard(market: items[i], onTap: () => onOpen(items[i])),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final PointOfSale market;
  final VoidCallback onTap;

  const _MarketCard({required this.market, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront,
                    size: 20,
                    color: market.isActive ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      market.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!market.isActive)
                    Text(
                      'Retired',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                market.locationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // A market with no fridges cannot be captured against. Better to
              // say so here than to let a rep find out at the shelf.
              if (market.hasNoFridges)
                _Pill(
                  icon: Icons.warning_amber_rounded,
                  label: 'No fridges yet',
                  color: scheme.error,
                )
              else
                _Pill(
                  icon: Icons.kitchen_outlined,
                  label: switch (market.fridgeCount) {
                    null => 'Open to manage',
                    1 => '1 fridge',
                    final n => '$n fridges',
                  },
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
