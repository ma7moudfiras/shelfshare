import 'package:flutter/material.dart';

/// A list with nothing in it, explained.
///
/// Shared so every empty list in the app says why it is empty and what would
/// fill it, rather than leaving a blank panel that looks like a failure.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Scrollable so it still works as the child of a RefreshIndicator: an
    // empty list is exactly when someone wants to pull to refresh.
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      children: [
        Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
