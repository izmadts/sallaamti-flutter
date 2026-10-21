import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// A genuine Facebook SDK failure (bad config, key hash mismatch, network
// error, app not set up right — anything other than the user tapping
// Cancel) — carries the SDK's own LoginResult.message, which was
// previously discarded entirely (both 'cancelled' and 'failed' silently
// returned null), leaving a real error indistinguishable from the user
// just backing out, and no way to see what Facebook actually said.
class FacebookAuthException implements Exception {
  final String message;
  FacebookAuthException(this.message);
}

// Thin wrapper around the two native SDKs — each method returns the raw
// token the backend verifies (Google ID token / Facebook access token), or
// null if the user cancelled. Real sign-in only works once the app is
// registered with its own mobile OAuth client IDs in the Google Cloud and
// Facebook Developer consoles (see AppConfig / config/services.php's
// mobile_client_ids comment on the backend) — until then this will throw,
// which callers surface as a normal error message, not a crash.
class SocialAuthService {
  static bool _googleInitialized = false;

  // The Web application OAuth client (sallaamti-ec3f4 project) — google_sign_in
  // v7's Credential Manager-based flow only returns a usable idToken when a
  // serverClientId is supplied here; without it, authentication() succeeds
  // but authentication.idToken comes back null. This is also exactly the ID
  // that must match Api\V1\AuthController's GOOGLE_MOBILE_CLIENT_IDS on the
  // backend, since it becomes the token's `aud` claim.
  static const _googleServerClientId = '237871727716-vts7t28rj7q36l8t5rpedf3uep2v7gi0.apps.googleusercontent.com';

  static Future<String?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;

    if (!_googleInitialized) {
      await googleSignIn.initialize(serverClientId: _googleServerClientId);
      _googleInitialized = true;
    }

    final account = await googleSignIn.authenticate();
    return account.authentication.idToken;
  }

  static Future<String?> signInWithFacebook() async {
    // webOnly (not the default nativeWithFallback) — when the Facebook app
    // is also installed, Android can route the OAuth callback into IT
    // instead of back to this app, since both register a handler for the
    // same fb<APP_ID>:// scheme; the login then dead-ends in the Facebook
    // app instead of returning a token here. Forcing the Custom Tab/web
    // flow the whole way through avoids the native handoff entirely.
    final result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
      loginBehavior: LoginBehavior.webOnly,
    );

    switch (result.status) {
      case LoginStatus.success:
        return result.accessToken?.tokenString;
      case LoginStatus.cancelled:
        // The user genuinely backed out — nothing to explain.
        return null;
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        // A real failure — surface the SDK's own message instead of
        // silently landing back on the login screen with no explanation.
        throw FacebookAuthException(result.message ?? 'Facebook sign-in failed (${result.status.name}).');
    }
  }
}
