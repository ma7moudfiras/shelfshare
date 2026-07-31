import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_storage_stub.dart'
    if (dart.library.js_interop) 'auth_storage_web.dart';

/// Storage for the session and for the OAuth code verifier.
///
/// Supabase defaults both to `shared_preferences`, and on our web build that
/// plugin is not registered at runtime: the very first call fails with
///
///   MissingPluginException(No implementation found for method getAll
///   on channel plugins.flutter.io/shared_preferences)
///
/// It breaks two things at once, and neither failure names the cause. Starting
/// a Google sign-in throws before the browser is ever sent to Google, so the
/// button appears to do nothing at all -- there is no request, no redirect and
/// no error the user can act on. And a signed-in session is never written, so
/// reloading the page signs you straight back out.
///
/// The browser already has storage that needs no plugin, so on web we use it
/// directly. Everywhere else the defaults are fine and are left alone.
FlutterAuthClientOptions authClientOptions() => platformAuthClientOptions();

/// Sends the browser to [url], replacing the current page.
///
/// Web only. See the implementation for why the OAuth hand-off does not go
/// through `url_launcher`.
void navigateWholePage(String url) => platformNavigate(url);
