import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_monitor/models/user_profile.dart';
import 'package:shelf_monitor/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal stand-ins for the two client members the signed-out path touches.
///
/// `refreshProfile` returns before reaching the database when there is no
/// user, so nothing here needs a working Postgrest.
class _FakeAuth implements GoTrueClient {
  final _events = StreamController<AuthState>.broadcast();

  User? user;

  @override
  Stream<AuthState> get onAuthStateChange => _events.stream;

  @override
  User? get currentUser => user;

  void fire(AuthChangeEvent event) => _events.add(AuthState(event, null));

  Future<void> close() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClient implements SupabaseClient {
  final _FakeAuth _auth;

  _FakeClient(this._auth);

  @override
  GoTrueClient get auth => _auth;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuth auth;
  late SupabaseAuthService service;

  setUp(() {
    auth = _FakeAuth();
    service = SupabaseAuthService(client: _FakeClient(auth));
  });

  tearDown(() async {
    service.dispose();
    await auth.close();
  });

  // The regression this exists for: AuthGate holds a StreamBuilder on
  // profileChanges and shows its splash until the first event lands. The
  // service used to ignore initialSession, which fires exactly once on cold
  // start -- so a visitor who was not already signed in got a spinner that
  // never resolved. It was invisible for as long as the deployment had no
  // Supabase credentials, because then the gate was never used at all.
  test('initialSession emits, so a cold start never hangs on the splash', () {
    expectLater(service.profileChanges, emits(isNull));
    auth.fire(AuthChangeEvent.initialSession);
  });

  test('signedOut emits null', () {
    expectLater(service.profileChanges, emits(isNull));
    auth.fire(AuthChangeEvent.signedOut);
  });

  test('every cold-start event produces exactly one emission', () async {
    final seen = <UserProfile?>[];
    final sub = service.profileChanges.listen(seen.add);

    auth.fire(AuthChangeEvent.initialSession);
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single, isNull);
    await sub.cancel();
  });

  test('currentProfile stays null while signed out', () async {
    auth.fire(AuthChangeEvent.initialSession);
    await Future<void>.delayed(Duration.zero);

    expect(service.currentProfile, isNull);
  });

  test('refreshProfile with no user emits rather than staying silent', () {
    expectLater(service.profileChanges, emits(isNull));
    service.refreshProfile();
  });
}
