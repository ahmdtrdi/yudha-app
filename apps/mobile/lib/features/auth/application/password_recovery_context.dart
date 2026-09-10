// Captured before Supabase consumes/clears callback URLs, including cold starts.
abstract final class PasswordRecoveryContext {
  static bool linkReceived = false;

  static bool detectAuthCallback(Uri uri) {
    final fragment = Uri.splitQueryString(uri.fragment);
    final hasAuthParameters =
        <String>['access_token', 'code', 'error', 'error_description'].any(
          (key) =>
              uri.queryParameters.containsKey(key) || fragment.containsKey(key),
        );
    if (hasAuthParameters &&
        (uri.host == 'reset-callback' ||
            uri.path == '/reset-password' ||
            fragment['type'] == 'recovery' ||
            uri.queryParameters['type'] == 'recovery')) {
      linkReceived = true;
    }
    return hasAuthParameters;
  }
}
