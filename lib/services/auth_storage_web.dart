import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

/// Uses the browser's own storage rather than the `shared_preferences` plugin.
///
/// See [authClientOptions] for why: the plugin is not registered in our web
/// build, so the first call throws `MissingPluginException` and takes both
/// Google sign-in and session persistence down with it.
FlutterAuthClientOptions platformAuthClientOptions() =>
    const FlutterAuthClientOptions(
      localStorage: _BrowserLocalStorage(),
      pkceAsyncStorage: _BrowserAsyncStorage(),
    );

/// Namespaced so this cannot collide with anything else on the origin.
const _sessionKey = 'shelfmonitor.supabase.session';
const _pkcePrefix = 'shelfmonitor.supabase.';

/// Where the session lives between page loads.
///
/// `localStorage`, not `sessionStorage`: a rep should not be signed out by
/// closing a tab, and an admin should not lose their place on a refresh.
class _BrowserLocalStorage extends LocalStorage {
  const _BrowserLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      web.window.localStorage.getItem(_sessionKey) != null;

  @override
  Future<String?> accessToken() async =>
      web.window.localStorage.getItem(_sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) async =>
      web.window.localStorage.setItem(_sessionKey, persistSessionString);

  @override
  Future<void> removePersistedSession() async =>
      web.window.localStorage.removeItem(_sessionKey);
}

/// Holds the PKCE code verifier for the few seconds between leaving for Google
/// and coming back.
///
/// This is the one the Google button actually needed: without somewhere to put
/// the verifier, building the authorize URL throws and the browser never
/// leaves the page.
class _BrowserAsyncStorage extends GotrueAsyncStorage {
  const _BrowserAsyncStorage();

  @override
  Future<String?> getItem({required String key}) async =>
      web.window.localStorage.getItem('$_pkcePrefix$key');

  @override
  Future<void> setItem({required String key, required String value}) async =>
      web.window.localStorage.setItem('$_pkcePrefix$key', value);

  @override
  Future<void> removeItem({required String key}) async =>
      web.window.localStorage.removeItem('$_pkcePrefix$key');
}

/// Sends the whole tab to [url].
///
/// Used instead of `url_launcher` for the OAuth hand-off. That package reaches
/// the browser through a plugin, and in this build the plugin is not reachable
/// -- launching threw `MissingPluginException(... method launch on channel
/// plugins.flutter.io/url_launcher)`, so the browser never left the page and
/// the Google button looked inert.
///
/// Navigating directly is also simply what an OAuth redirect is: the supabase
/// JavaScript client does the same thing in a browser. There is nothing to
/// launch, only a page to go to.
void platformNavigate(String url) => web.window.location.assign(url);
