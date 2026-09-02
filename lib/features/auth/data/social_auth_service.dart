import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);

    if (result.status == LoginStatus.success) {
      return result.accessToken?.tokenString;
    }

    return null;
  }
}
