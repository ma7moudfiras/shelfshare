import 'package:flutter/material.dart';

/// Shown when the app was built without Supabase credentials.
///
/// This is a deliberate dead end. The alternative -- carrying on into the
/// capture screen -- is what a missing environment variable used to do, and it
/// published an app with no sign-in and a live inference budget behind it. A
/// build that cannot authenticate anyone should be visibly broken, not quietly
/// open.
class BackendMissingScreen extends StatelessWidget {
  const BackendMissingScreen({super.key});

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
                    Icons.cloud_off_outlined,
                    size: 46,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'This build has no backend',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Shelf Monitor cannot sign anyone in, so it will not '
                    'start. This is a deployment problem, not something you '
                    'can fix from here -- please tell whoever set the app up.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
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
