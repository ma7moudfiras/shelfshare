import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Raised when sign-in fails for a reason worth showing the user.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

/// Authentication and the signed-in user's profile.
///
/// Deliberately thin: it authenticates and reports who the user is. It grants
/// nothing. Every permission decision happens in Postgres via Row Level
/// Security, so a client that lied about its role would still read nothing.
abstract interface class AuthService {
  /// Emits on sign-in, sign-out and token refresh. Null means signed out.
  Stream<UserProfile?> get profileChanges;

  /// The current profile, or null when signed out.
  UserProfile? get currentProfile;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Emails a link to set or reset a password.
  ///
  /// There is no registration: this is also how someone whose account an admin
  /// created chooses their own password, so no one has to hand a credential
  /// over in a message.
  Future<void> sendPasswordReset(String email);

  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Re-reads the profile from the database.
  ///
  /// Needed because an admin assigning a company does not touch the user's
  /// session -- without this the app would keep showing "awaiting access"
  /// until the user signed out and back in.
  Future<UserProfile?> refreshProfile();

  void dispose();
}

class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;

  final _controller = StreamController<UserProfile?>.broadcast();
  StreamSubscription<AuthState>? _authSub;

  UserProfile? _profile;

  SupabaseAuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client {
    _authSub = _client.auth.onAuthStateChange.listen(_handleAuthChange);
    // Pick up a session restored from storage on cold start.
    if (_client.auth.currentUser != null) unawaited(refreshProfile());
  }

  @override
  Stream<UserProfile?> get profileChanges => _controller.stream;

  @override
  UserProfile? get currentProfile => _profile;

  Future<void> _handleAuthChange(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        await refreshProfile();
      case AuthChangeEvent.signedOut:
        _emit(null);
      default:
        break;
    }
  }

  void _emit(UserProfile? profile) {
    _profile = profile;
    if (!_controller.isClosed) _controller.add(profile);
  }

  @override
  Future<UserProfile?> refreshProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _emit(null);
      return null;
    }

    try {
      final row = await _client
          .from('profiles')
          .select('id, role, company_id, full_name, email, is_active, '
              'companies(name)')
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        // The handle_new_user trigger should always have created a row. If it
        // somehow has not, treat the user as pending rather than crashing --
        // pending grants nothing, so this fails safe.
        _emit(UserProfile(
          id: user.id,
          role: UserRole.pending,
          email: user.email,
        ));
        return _profile;
      }

      _emit(UserProfile.fromJson(row));
      return _profile;
    } on PostgrestException catch (e) {
      debugPrint('Profile lookup failed: ${e.message}');
      // Never leave a stale profile behind on failure: showing the previous
      // user's role would be worse than showing none.
      _emit(null);
      return null;
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        // On web the browser returns to the app's own origin; on native the
        // deep link is registered per platform. Null lets the SDK choose the
        // right default for the platform it is running on.
        redirectTo: kIsWeb ? null : 'io.supabase.shelfmonitor://login-callback/',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  /// Supabase messages are usable but terse; a few common ones deserve better.
  String _friendly(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'That email and password do not match an account.';
    }
    if (message.contains('email not confirmed')) {
      return 'Check your inbox and confirm your email address first.';
    }
    if (message.contains('signups not allowed') ||
        message.contains('signup is disabled')) {
      return 'Accounts are created by an administrator. Ask them to add you.';
    }
    if (message.contains('provider is not enabled')) {
      return 'Google sign-in is not enabled for this project yet.';
    }
    return e.message;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _controller.close();
  }
}
