import 'package:flutter/material.dart';

/// A screen-filling failure, with the way out.
///
/// Scrollable so it still works inside a [RefreshIndicator] -- a failed load is
/// exactly when someone reaches for pull-to-refresh.
class ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      children: [
        Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
