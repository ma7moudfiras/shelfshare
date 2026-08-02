import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../services/market_service.dart';
import '../services/visit_service.dart';
import 'admin_dashboard_screen.dart';
import 'company_request_screen.dart';
import 'pending_screen.dart';
import 'rep_home_screen.dart';
import 'sign_in_screen.dart';

/// Decides what a user sees based on who they are.
///
/// This is convenience, not security. A user who forced their way past this
/// gate would still read nothing: every table is protected by Row Level
/// Security, so the database refuses regardless of what the client renders.
class AuthGate extends StatelessWidget {
  final AuthService authService;
  final DetectionService? detectionService;

  /// Supplied by [main]. Nullable only so tests can omit them when the route
  /// under test never reaches a dashboard.
  final AdminService? adminService;
  final MarketService? marketService;
  final VisitService? visitService;

  const AuthGate({
    super.key,
    required this.authService,
    this.detectionService,
    this.adminService,
    this.marketService,
    this.visitService,
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
        final markets = marketService;
        final visits = visitService;

        return switch (profile.role) {
          // Reps used to land straight on the camera, on the reasoning that
          // every screen between them and the shutter costs a visit. It also
          // cost the data: a photo with no market, fridge or visit attached
          // cannot be stored. Choosing where you are comes first now.
          UserRole.salesRep when visits != null => RepHomeScreen(
            profile: profile,
            authService: authService,
            visitService: visits,
            detectionService: detectionService,
          ),

          // Both admin roles share one dashboard. What they can see differs,
          // but Row Level Security decides that, not this switch.
          UserRole.companyAdmin ||
          UserRole.platformAdmin when admin != null && markets != null =>
            AdminDashboardScreen(
              profile: profile,
              authService: authService,
              adminService: admin,
              marketService: markets,
              detectionService: detectionService,
            ),

          // Only reachable if the app was built without those services, which
          // main() does not do once the backend is up.
          UserRole.salesRep ||
          UserRole.companyAdmin ||
          UserRole.platformAdmin => const _Splash(),

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
