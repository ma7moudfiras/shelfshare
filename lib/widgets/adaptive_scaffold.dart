import 'package:flutter/material.dart';

import '../theme/layout.dart';

/// One destination in the app's primary navigation.
class AdaptiveDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Shown as a badge when greater than zero. Used for things that go stale if
  /// ignored, which in practice means somebody is waiting on the other end.
  final int badgeCount;

  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// A scaffold whose navigation follows the size of the window.
///
/// The app is used in two genuinely different places -- a phone held in a shop
/// aisle, and a browser on a desk -- and the same layout cannot serve both. A
/// bottom bar stranded at the foot of a 27-inch monitor is the giveaway that a
/// mobile layout has been stretched rather than adapted, so above the compact
/// breakpoint navigation moves to a side rail and the content stops spanning
/// the full width.
///
/// The switch keys off window width rather than platform, so a browser window
/// dragged narrow becomes the phone layout, which is also how it gets tested.
class AdaptiveScaffold extends StatelessWidget {
  final String title;

  /// Small line under the title, e.g. the signed-in role and company.
  final String? subtitle;

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.layoutSize;
    final theme = Theme.of(context);

    final appBar = AppBar(
      title: Text(title),
      actions: actions,
      // The rail already names every destination, so the subtitle is the only
      // thing this strip carries there.
      bottom: subtitle == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(30),
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
    );

    if (!layout.usesRail) {
      return Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: _badged(d, Icon(d.icon)),
                selectedIcon: _badged(d, Icon(d.selectedIcon)),
                label: d.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            // Labels ride alongside the icons once there is room for them; at
            // medium width they sit underneath so the rail stays narrow.
            extended: layout.isWide,
            labelType: layout.isWide
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            minExtendedWidth: 190,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: _badged(d, Icon(d.icon)),
                  selectedIcon: _badged(d, Icon(d.selectedIcon)),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _badged(AdaptiveDestination destination, Widget child) {
    if (destination.badgeCount <= 0) return child;
    return Badge(label: Text('${destination.badgeCount}'), child: child);
  }
}
