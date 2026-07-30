import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// Shown to a signed-in user who has no access yet.
///
/// Anyone can sign in with Google, so authentication cannot imply
/// authorisation. This screen is the honest expression of that: the account
/// exists, it simply has not been attached to a company. It is also what a
/// deactivated user sees, so revoking someone does not require changing their
/// role as well.
class PendingScreen extends StatefulWidget {
  final UserProfile profile;
  final AuthService authService;

  const PendingScreen({
    super.key,
    required this.profile,
    required this.authService,
  });

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  bool _isChecking = false;

  /// An admin granting access does not touch this user's session, so nothing
  /// would tell the app to move on. Re-reading the profile on demand is what
  /// avoids "sign out and back in again" as the instruction.
  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);
    await widget.authService.refreshProfile();
    if (mounted) setState(() => _isChecking = false);
  }

  /// Sends the user back to the picker by withdrawing the request.
  Future<void> _clearRequest() async {
    setState(() => _isChecking = true);
    await widget.authService.requestAccess('');
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final isDeactivated = !profile.isActive;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDeactivated
                        ? Icons.no_accounts_outlined
                        : Icons.hourglass_empty,
                    size: 46,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isDeactivated
                        ? 'Your access has been turned off'
                        : 'Waiting for approval',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isDeactivated
                        ? 'An administrator has deactivated this account. '
                              'Contact them if you think this is a mistake.'
                        : profile.requestedCompanyName != null
                        ? 'Your request has been sent to '
                              '${profile.requestedCompanyName}. An '
                              'administrator there will approve it and set '
                              'what you can do.'
                        : 'Your request has been sent. An administrator will '
                              'approve it and set what you can do.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // The email is what an admin needs in order to find and
                  // assign this person, so make it easy to read out or copy.
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
                          'Give this to your administrator',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          profile.email ?? profile.id,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  if (!isDeactivated)
                    FilledButton.icon(
                      onPressed: _isChecking ? null : _checkAgain,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_isChecking ? 'Checking…' : 'Check again'),
                    ),
                  // Picking the wrong company should not be a dead end that
                  // requires an admin to notice and fix.
                  if (!isDeactivated && profile.hasRequestedAccess)
                    TextButton(
                      onPressed: _isChecking ? null : _clearRequest,
                      child: const Text('Choose a different company'),
                    ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: widget.authService.signOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
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
