import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import 'admin_dashboard_screen.dart';
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

  /// Supplied by [main]. Nullable only so tests can omit it when the route
  /// under test never reaches a dashboard.
  final AdminService? adminService;

  const AuthGate({
    super.key,
    required this.authService,
    this.detectionService,
    this.adminService,
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

        final admin = adminService;

        return switch (profile.role) {
          // Reps go straight to the camera: their job is capture, and every
          // extra screen between them and the shutter costs a visit.
          UserRole.salesRep => CaptureScreen(detectionService: detectionService),

          // Both admin roles share one dashboard. What they can see differs,
          // but Row Level Security decides that, not this switch.
          UserRole.companyAdmin || UserRole.platformAdmin when admin != null =>
            AdminDashboardScreen(
              profile: profile,
              authService: authService,
              adminService: admin,
              detectionService: detectionService,
            ),

          // Only reachable if the app was built without an admin service,
          // which main() does not do once the backend is up.
          UserRole.companyAdmin || UserRole.platformAdmin => const _Splash(),

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
