import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import 'empty_state.dart';

/// The approval queue: people waiting to be let into a company.
///
/// Approving asks for a role rather than assuming one. "Approve" alone would
/// have to pick silently, and the difference between a rep and another admin is
/// not a detail worth guessing on someone's behalf.
class AccessRequestList extends StatelessWidget {
  /// Null while loading.
  final List<UserProfile>? requests;
  final bool isBusy;

  /// Platform admins see requests for every company, so they need to know which
  /// one each request is for. A company admin only ever sees their own.
  final bool showCompany;

  final void Function(UserProfile user, UserRole role) onApprove;
  final void Function(UserProfile user) onDecline;

  const AccessRequestList({
    super.key,
    required this.requests,
    required this.isBusy,
    required this.showCompany,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final items = requests;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No one is waiting',
        message:
            'When someone signs in and asks to join, their request appears '
            'here for you to approve.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _RequestTile(
        user: items[i],
        isBusy: isBusy,
        showCompany: showCompany,
        onApprove: onApprove,
        onDecline: onDecline,
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final UserProfile user;
  final bool isBusy;
  final bool showCompany;
  final void Function(UserProfile user, UserRole role) onApprove;
  final void Function(UserProfile user) onDecline;

  const _RequestTile({
    required this.user,
    required this.isBusy,
    required this.showCompany,
    required this.onApprove,
    required this.onDecline,
  });

  Future<void> _confirmDecline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline this request?'),
        content: Text(
          '${user.displayName} keeps their account and can ask again, '
          'including a different company. Nothing is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) onDecline(user);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.displayName.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // The email is what identifies this person to an admin who
                    // is deciding whether they recognise them.
                    if (user.email != null)
                      Text(
                        user.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (showCompany && user.requestedCompanyName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Asking to join ${user.requestedCompanyName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isBusy ? null : () => _confirmDecline(context),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              MenuAnchor(
                menuChildren: [
                  for (final role in const [
                    UserRole.salesRep,
                    UserRole.companyAdmin,
                  ])
                    MenuItemButton(
                      onPressed: isBusy ? null : () => onApprove(user, role),
                      child: Text('Approve as ${role.label.toLowerCase()}'),
                    ),
                ],
                builder: (context, controller, _) => FilledButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
