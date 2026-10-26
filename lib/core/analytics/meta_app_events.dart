import 'package:facebook_app_events/facebook_app_events.dart';

// Install/activation tracking only, for Meta Ads attribution — not
// Facebook Login (flutter_facebook_auth, dropped for recurring native-SDK/
// key-hash crashes, stays removed). The native SDK auto-logs its own
// install/open signals once initialized via the ApplicationId in
// AndroidManifest.xml; logging this event explicitly here is just the one
// extra, Meta-documented call on top of that (AppEventsConstants
// .EVENT_NAME_ACTIVATED_APP on the native side — this package has no
// named constant for it, so the raw event name is used directly).
Future<void> initMetaAppEvents() async {
  try {
    await FacebookAppEvents().logEvent(name: 'fb_mobile_activate_app');
  } catch (_) {
    // Never block app startup over an ad-attribution signal.
  }
}
