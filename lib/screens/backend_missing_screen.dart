import 'package:flutter/material.dart';

import '../main.dart' show BackendStatus;

/// Shown when the app has no usable backend, for either of two reasons.
///
/// **Not configured.** The build carries no Supabase credentials. This is a
/// deliberate dead end: the alternative -- carrying on into the capture screen
/// -- is what a missing environment variable used to do, and it published an
/// app with no sign-in and a live inference budget behind it. A build that
/// cannot authenticate anyone should be visibly broken, not quietly open.
///
/// **Unreachable.** Credentials are present but the server did not answer. That
/// is very often just a bad signal inside a shop, so this one offers a retry
/// and says so in those terms rather than blaming the operator.
class BackendMissingScreen extends StatelessWidget {
  final BackendStatus status;

  /// Restarts the app's connection attempt. Defaults to a full reload, which is
  /// the only way back once `Supabase.initialize` has failed -- its client is
  /// not re-initialisable in place.
  final VoidCallback? onRetry;

  const BackendMissingScreen({
    super.key,
    required this.status,
    this.onRetry,
  });

  bool get _isUnreachable => status == BackendStatus.unreachable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isUnreachable
                        ? Icons.wifi_off_outlined
                        : Icons.cloud_off_outlined,
                    size: 46,
                    color: _isUnreachable
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isUnreachable
                        ? 'Cannot reach the server'
                        : 'This build has no backend',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isUnreachable
                        ? 'Shelf Monitor could not sign you in because it '
                              'could not connect. This is usually signal -- '
                              'step outside or onto Wi-Fi and try again.'
                        : 'Shelf Monitor cannot sign anyone in, so it will '
                              'not start. This is a deployment problem, not '
                              'something you can fix from here -- please tell '
                              'whoever set the app up.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),

                  if (_isUnreachable)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Try again'),
                    )
                  else
                    // Naming the variables turns a support conversation into a
                    // one-line fix for whoever deployed this.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Missing at build time',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SelectableText(
                            'SUPABASE_URL\nSUPABASE_PUBLISHABLE_KEY',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
