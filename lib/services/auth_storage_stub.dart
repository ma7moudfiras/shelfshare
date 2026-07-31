import 'package:supabase_flutter/supabase_flutter.dart';

/// Non-web platforms keep Supabase's defaults.
///
/// `shared_preferences` works there, and its native implementations are the
/// right place to store a session -- on iOS and Android that is what the
/// platform expects and what survives an app upgrade.
FlutterAuthClientOptions platformAuthClientOptions() =>
    const FlutterAuthClientOptions();

/// Never called off the web: native sign-in uses the platform's own browser
/// via url_launcher, which works there.
Never platformNavigate(String url) =>
    throw UnsupportedError('Whole-page navigation only exists on the web.');
