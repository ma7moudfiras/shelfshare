import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company_option.dart';
import '../models/user_profile.dart';
import 'auth_storage.dart';

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

  /// Companies a pending user may request access to.
  ///
  /// Readable only while pending, and only active companies, so the list is
  /// the smallest disclosure that still makes the picker work.
  Future<List<CompanyOption>> availableCompanies();

  /// Records which company this user is asking to join.
  ///
  /// Grants nothing. It routes the request to that company's administrator
  /// instead of leaving it in one global queue. An empty [companyId] withdraws
  /// the request, sending the user back to the picker -- choosing the wrong
  /// company should not be a dead end only an admin can clear.
  Future<void> requestAccess(String companyId);

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
      // initialSession fires once on cold start, with or without a restored
      // session, and it MUST emit. AuthGate holds a StreamBuilder on this
      // stream and shows its splash until the first event arrives -- so
      // letting this case fall through leaves every visitor who is not already
      // signed in staring at a spinner that never resolves.
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        // Emits null by itself when there is no user, which is the signed-out
        // case and sends the gate to the sign-in screen.
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
          .select(
            'id, role, company_id, full_name, email, is_active, '
            'requested_company_id, '
            'companies!profiles_company_id_fkey(name), '
            'requested_company:companies!profiles_requested_company_id_fkey(name)',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        // The handle_new_user trigger should always have created a row. If it
        // somehow has not, treat the user as pending rather than crashing --
        // pending grants nothing, so this fails safe.
        _emit(
          UserProfile(id: user.id, role: UserRole.pending, email: user.email),
        );
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
    } catch (error) {
      // Anything else here is essentially always the network -- no signal, DNS,
      // TLS. It has to be caught for the same reason initialSession has to be
      // handled: this runs inside the auth listener, so an escaping error emits
      // nothing and the gate waits on its splash forever. Failing to null sends
      // the user to sign-in, where trying again produces a real message.
      debugPrint('Profile lookup failed: $error');
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
  Future<List<CompanyOption>> availableCompanies() async {
    try {
      final rows = await _client
          .from('companies')
          .select('id, name')
          .order('name');
      return rows.map((r) => CompanyOption.fromJson(r)).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('Company list failed: ${e.message}');
      return const [];
    }
  }

  @override
  Future<void> requestAccess(String companyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('You are not signed in.');

    try {
      final withdrawing = companyId.isEmpty;
      await _client
          .from('profiles')
          .update({
            'requested_company_id': withdrawing ? null : companyId,
            'requested_at': withdrawing
                ? null
                : DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
      await refreshProfile();
    } on PostgrestException catch (e) {
      throw AuthFailure('Could not send the request: ${e.message}');
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
      if (kIsWeb) {
        // Build the URL and go there ourselves. signInWithOAuth would do the
        // same thing but hands the last step to url_launcher, whose plugin is
        // not reachable in this build -- it threw MissingPluginException and
        // the browser never left the page, so the button did nothing at all.
        final oauth = await _client.auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        navigateWholePage(oauth.url);
        return;
      }

      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        // Native returns through a deep link registered per platform.
        redirectTo: 'io.supabase.shelfmonitor://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
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
