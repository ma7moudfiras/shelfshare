import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/user_profile.dart';
import 'package:shelf_monitor/screens/auth_gate.dart';
import 'package:shelf_monitor/screens/pending_screen.dart';
import 'package:shelf_monitor/screens/sign_in_screen.dart';
import 'package:shelf_monitor/services/auth_service.dart';

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
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void dispose() => _controller.close();
}

UserProfile profileWith(
  UserRole role, {
  bool isActive = true,
  String? companyId = 'company-1',
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
  );
}

Future<void> pumpGate(WidgetTester tester, FakeAuthService auth) async {
  await tester.pumpWidget(MaterialApp(home: AuthGate(authService: auth)));
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

    testWidgets('pending user is held at the waiting screen', (tester) async {
      final auth = FakeAuthService();
      await pumpGate(tester, auth);
      auth.emit(profileWith(UserRole.pending));
      await tester.pump();

      expect(find.byType(PendingScreen), findsOneWidget);
      expect(find.text('Waiting for access'), findsOneWidget);
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
      expect(find.textContaining('Signed in as'), findsOneWidget);
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

  group('PendingScreen', () {
    // An admin granting access does not touch the user's session, so without a
    // re-check the only way forward would be signing out and back in.
    testWidgets('check again re-reads the profile', (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: PendingScreen(
            profile: profileWith(UserRole.pending),
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
            profile: profileWith(UserRole.pending),
            authService: auth,
          ),
        ),
      );

      expect(find.text('test@example.com'), findsOneWidget);
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
