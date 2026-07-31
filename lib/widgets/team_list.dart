import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import 'empty_state.dart';

/// Everyone who already has access, and the switch that takes it away.
///
/// Deactivating rather than deleting is deliberate: a rep's captures are
/// history that has to stay attributable, so accounts are switched off, never
/// removed.
class TeamList extends StatelessWidget {
  /// Null while loading.
  final List<UserProfile>? members;
  final bool isBusy;
  final bool showCompany;

  /// Used to stop an admin switching off their own account, which would lock
  /// them out of the screen they would need to switch it back on.
  final String currentUserId;

  final void Function(UserProfile user, bool isActive) onSetActive;

  const TeamList({
    super.key,
    required this.members,
    required this.isBusy,
    required this.showCompany,
    required this.currentUserId,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    final items = members;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No one here yet',
        message:
            'Approved users appear here. Approve a request to add your first '
            'team member.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final user = items[i];
        final isSelf = user.id == currentUserId;
        final theme = Theme.of(context);

        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: user.isActive
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              user.displayName.characters.first.toUpperCase(),
              style: TextStyle(
                color: user.isActive
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  user.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: user.isActive
                        ? null
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (isSelf)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '(you)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            [
              user.role.label,
              if (showCompany && user.companyName != null) user.companyName!,
              if (!user.isActive) 'deactivated',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: user.isActive
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
          trailing: Switch(
            value: user.isActive,
            // Switching yourself off would be a one-way door out of this
            // screen, so it is simply not offered.
            onChanged: isBusy || isSelf
                ? null
                : (value) => onSetActive(user, value),
          ),
        );
      },
    );
  }
}
