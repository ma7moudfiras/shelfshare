import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/company_option.dart';
import 'package:shelf_monitor/models/user_profile.dart';
import 'package:shelf_monitor/screens/admin_dashboard_screen.dart';
import 'package:shelf_monitor/screens/auth_gate.dart';
import 'package:shelf_monitor/screens/company_request_screen.dart';
import 'package:shelf_monitor/screens/pending_screen.dart';
import 'package:shelf_monitor/screens/sign_in_screen.dart';
import 'package:shelf_monitor/services/auth_service.dart';

import 'admin_dashboard_screen_test.dart' show FakeAdminService;

class FakeAuthService implements AuthService {
  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _profile;
  int refreshCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<UserProfile?> get profileChanges => _controller.stream;

  @override
  UserProfile? get currentProfile => _profile;

  void emit(UserProfile? profile) {
    _profile = profile;
    _controller.add(profile);
  }

  @override
  Future<UserProfile?> refreshProfile() async {
    refreshCalls++;
    return _profile;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(null);
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  List<CompanyOption> companies = const [
    CompanyOption(id: 'c-unipal', name: 'UniPal'),
    CompanyOption(id: 'c-npc', name: 'NPC'),
  ];
  String? requestedCompanyId;
  int requestCalls = 0;

  @override
  Future<List<CompanyOption>> availableCompanies() async => companies;

  @override
  Future<void> requestAccess(String companyId) async {
    requestCalls++;
    requestedCompanyId = companyId.isEmpty ? null : companyId;
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void dispose() => _controller.close();
}

UserProfile profileWith(
  UserRole role, {
  bool isActive = true,
  String? companyId = 'company-1',
  String? requestedCompanyId,
  String? requestedCompanyName,
}) {
  return UserProfile(
    id: 'user-1',
    role: role,
    companyId: role == UserRole.platformAdmin || role == UserRole.pending
        ? null
        : companyId,
    companyName: 'UniPal',
    fullName: 'Test User',
    email: 'test@example.com',
    isActive: isActive,
    requestedCompanyId: requestedCompanyId,
    requestedCompanyName: requestedCompanyName,
  );
}

Future<void> pumpGate(WidgetTester tester, FakeAuthService auth) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuthGate(
        authService: auth,
        // Admin routes render a real dashboard, which needs a service. A fake
        // keeps the gate's routing testable without a database.
        adminService: FakeAdminService(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('UserRole.fromDb', () {
    test('maps the Postgres enum values', () {
      expect(UserRole.fromDb('platform_admin'), UserRole.platformAdmin);
      expect(UserRole.fromDb('company_admin'), UserRole.companyAdmin);
      expect(UserRole.fromDb('sales_rep'), UserRole.salesRep);
      expect(UserRole.fromDb('pending'), UserRole.pending);
    });

    // An unknown role must never open a door. If the database grows a role
    // this build has not heard of, the safe reading is "no access".
    test('falls back to the least-privileged role, never a permissive one', () {
      expect(UserRole.fromDb(null), UserRole.pending);
      expect(UserRole.fromDb(''), UserRole.pending);
      expect(UserRole.fromDb('superuser'), UserRole.pending);
      expect(UserRole.fromDb('PLATFORM_ADMIN'), UserRole.pending);
    });

    test('pending has no access', () {
      expect(UserRole.pending.hasAccess, isFalse);
      expect(UserRole.salesRep.hasAccess, isTrue);
    });
  });

  group('UserProfile', () {
    test('a deactivated user cannot use the app whatever their role', () {
      final admin = profileWith(UserRole.companyAdmin, isActive: false);

      // Revoking someone should not require also demoting them.
      expect(admin.role.hasAccess, isTrue);
      expect(admin.canUseApp, isFalse);
    });

    test('display name falls back through name, email, then a default', () {
      expect(profileWith(UserRole.salesRep).displayName, 'Test User');
      expect(
        const UserProfile(
          id: 'x',
          role: UserRole.salesRep,
          email: 'ahmad@shop.ps',
        ).displayName,
        'ahmad',
      );
      expect(
        const UserProfile(id: 'x', role: UserRole.salesRep).displayName,
        'User',
      );
    });

    test('parses a joined profiles row', () {
      final profile = UserProfile.fromJson({
        'id': 'abc',
        'role': 'company_admin',
        'company_id': 'c1',
        'full_name': 'Sara',
        'email': 'sara@unipal.ps',
        'is_active': true,
        'companies': {'name': 'UniPal'},
      });

      expect(profile.role, UserRole.companyAdmin);
      expect(profile.companyName, 'UniPal');
      expect(profile.canUseApp, isTrue);
    });
  });

  group('AuthGate routing', () {
    testWidgets('signed out shows sign-in', (tester) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(null);
      await tester.pump();

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    // A brand-new user has not said who they work for yet, so routing the
    // request is impossible until they do.
    testWidgets('pending user with no request picks a company first', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(profileWith(UserRole.pending));
      await tester.pump();

      expect(find.byType(CompanyRequestScreen), findsOneWidget);
      expect(find.byType(PendingScreen), findsNothing);
    });

    testWidgets('pending user who has requested waits for approval', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(profileWith(
        UserRole.pending,
        requestedCompanyId: 'c-unipal',
        requestedCompanyName: 'UniPal',
      ));
      await tester.pump();

      expect(find.byType(PendingScreen), findsOneWidget);
      expect(find.text('Waiting for approval'), findsOneWidget);
      // Naming the company confirms the request went where they expected.
      expect(find.textContaining('UniPal'), findsOneWidget);
    });

    // Being deactivated is not the same as being new: asking a former user to
    // choose a company again would imply their account had been reset.
    testWidgets('a deactivated user is not sent to the company picker', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(profileWith(UserRole.salesRep, isActive: false));
      await tester.pump();

      expect(find.byType(CompanyRequestScreen), findsNothing);
      expect(find.byType(PendingScreen), findsOneWidget);
    });

    // Anyone can sign in with Google, so authentication must not imply access.
    testWidgets('a deactivated user is held even with a real role', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(profileWith(UserRole.companyAdmin, isActive: false));
      await tester.pump();

      expect(find.byType(PendingScreen), findsOneWidget);
      expect(find.text('Your access has been turned off'), findsOneWidget);
    });

    testWidgets('company admin reaches the app, not the waiting screen', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(profileWith(UserRole.companyAdmin));
      await tester.pump();

      expect(find.byType(PendingScreen), findsNothing);
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
    });

    testWidgets('signing out returns to sign-in', (tester) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(profileWith(UserRole.companyAdmin));
      await tester.pump();

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pump();

      expect(auth.signOutCalls, 1);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('no self-registration', () {
    // Accounts are granted by an administrator. The button is gone, but note
    // this is presentation only -- the real guarantee is that a new account
    // lands with no company and no access, enforced by the database.
    testWidgets('offers no way to create an account', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: auth)),
      );

      expect(find.textContaining('Create'), findsNothing);
      expect(find.textContaining('Sign up'), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('says where accounts come from', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: auth)),
      );

      expect(
        find.textContaining('created by your administrator'),
        findsOneWidget,
      );
    });

    // Someone whose account an admin created still needs a password, and no
    // one should be handing credentials over in a message.
    testWidgets('offers a way to set a first password', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(authService: auth)),
      );

      expect(find.text('Set or reset password'), findsOneWidget);
    });
  });

  group('CompanyRequestScreen', () {
    testWidgets('lists companies and sends the request', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyRequestScreen(
            profile: profileWith(UserRole.pending),
            authService: auth,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('UniPal'), findsOneWidget);
      expect(find.text('NPC'), findsOneWidget);

      // Nothing can be submitted until a company is chosen: a request with no
      // destination could not be routed to anyone.
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('UniPal'));
      await tester.pump();
      await tester.tap(find.text('Request access'));
      await tester.pump();

      expect(auth.requestCalls, 1);
      expect(auth.requestedCompanyId, 'c-unipal');
    });

    testWidgets('explains itself when no companies exist yet', (tester) async {
      final auth = FakeAuthService()..companies = const [];
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyRequestScreen(
            profile: profileWith(UserRole.pending),
            authService: auth,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('No companies are set up'), findsOneWidget);
    });
  });

  group('PendingScreen', () {
    // An admin granting access does not touch the user's session, so without a
    // re-check the only way forward would be signing out and back in.
    testWidgets('check again re-reads the profile', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: PendingScreen(
            profile: profileWith(
              UserRole.pending,
              requestedCompanyId: 'c-unipal',
              requestedCompanyName: 'UniPal',
            ),
            authService: auth,
          ),
        ),
      );

      await tester.tap(find.text('Check again'));
      await tester.pump();

      expect(auth.refreshCalls, 1);
    });

    testWidgets('shows the email an admin needs to find this user', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: PendingScreen(
            profile: profileWith(
              UserRole.pending,
              requestedCompanyId: 'c-unipal',
            ),
            authService: auth,
          ),
        ),
      );

      expect(find.text('test@example.com'), findsOneWidget);
    });

    // Picking the wrong company must not be a dead end that only an admin can
    // clear.
    testWidgets('the request can be withdrawn to choose again', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: PendingScreen(
            profile: profileWith(
              UserRole.pending,
              requestedCompanyId: 'c-unipal',
              requestedCompanyName: 'UniPal',
            ),
            authService: auth,
          ),
        ),
      );

      await tester.tap(find.text('Choose a different company'));
      await tester.pump();

      expect(auth.requestCalls, 1);
      expect(auth.requestedCompanyId, isNull);
    });

    testWidgets('a deactivated user is not offered a pointless re-check', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: PendingScreen(
            profile: profileWith(UserRole.salesRep, isActive: false),
            authService: auth,
          ),
        ),
      );

      expect(find.text('Check again'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });
}
