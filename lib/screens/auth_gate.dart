import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import 'capture_screen.dart';
import 'company_request_screen.dart';
import 'pending_screen.dart';
import 'sign_in_screen.dart';

/// Decides what a user sees based on who they are.
///
/// This is convenience, not security. A user who forced their way past this
/// gate would still read nothing: every table is protected by Row Level
/// Security, so the database refuses regardless of what the client renders.
class AuthGate extends StatelessWidget {
  final AuthService authService;
  final DetectionService? detectionService;

  const AuthGate({
    super.key,
    required this.authService,
    this.detectionService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: authService.profileChanges,
      initialData: authService.currentProfile,
      builder: (context, snapshot) {
        // A restored session resolves asynchronously. Showing the sign-in
        // screen during that gap would flash it at an already-signed-in user
        // on every cold start.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _Splash();
        }

        final profile = snapshot.data;
        if (profile == null) return SignInScreen(authService: authService);

        if (!profile.canUseApp) {
          // A deactivated user is not asked to pick a company: they already
          // had one, and choosing again would imply their account is new.
          if (profile.isActive && !profile.hasRequestedAccess) {
            return CompanyRequestScreen(
              profile: profile,
              authService: authService,
            );
          }
          return PendingScreen(profile: profile, authService: authService);
        }

        return switch (profile.role) {
          // Reps go straight to the camera: their job is capture, and every
          // extra screen between them and the shutter costs a visit.
          UserRole.salesRep => CaptureScreen(detectionService: detectionService),

          // Dashboards are the next milestone; until then admins get an
          // honest placeholder rather than a broken screen.
          UserRole.companyAdmin || UserRole.platformAdmin => _ComingSoon(
            profile: profile,
            authService: authService,
            detectionService: detectionService,
          ),

          UserRole.pending => PendingScreen(
            profile: profile,
            authService: authService,
          ),
        };
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// Placeholder home for admin roles until dashboards exist.
///
/// Offers the capture screen too, so an admin can exercise the working part of
/// the app rather than hitting a dead end.
class _ComingSoon extends StatelessWidget {
  final UserProfile profile;
  final AuthService authService;
  final DetectionService? detectionService;

  const _ComingSoon({
    required this.profile,
    required this.authService,
    this.detectionService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Monitor'),
        actions: [
          IconButton(
            onPressed: authService.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 46,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 18),
              Text(
                'Signed in as ${profile.displayName}',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                [
                  profile.role.label,
                  if (profile.companyName != null) profile.companyName!,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Dashboards are not built yet. In the meantime you can use the '
                'capture screen to test detection.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CaptureScreen(detectionService: detectionService),
                  ),
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Open capture'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
