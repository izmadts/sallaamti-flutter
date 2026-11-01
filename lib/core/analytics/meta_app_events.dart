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

// CompleteRegistration — logged the moment a member finishes the Nikah
// wizard and submits their profile for verification (NikahReviewScreen's
// _submit()). That's the real "signed up for the thing we're actually
// advertising" moment for Meta's ad-campaign optimization, not the bare
// account registration/login, which fires no event of its own here.
Future<void> logNikahProfileCompleted({String? gender}) async {
  try {
    // One event, both params — logCompletedRegistration() alone only sets
    // fb_registration_method; this adds gender onto the same call instead
    // of firing a second CompleteRegistration (which would double-count
    // every submission for ad optimization).
    await FacebookAppEvents().logEvent(
      name: FacebookAppEvents.eventNameCompletedRegistration,
      parameters: {
        FacebookAppEvents.paramNameRegistrationMethod: 'nikah_profile',
        if (gender != null) 'gender': gender,
      },
    );
  } catch (_) {
    // Never block the wizard over an ad-attribution signal.
  }
}

// Purchase — logged when the member submits their verification-fee payment
// proof (NikahPaymentScreen's _submit()), not when admin later confirms it:
// confirmation happens in the admin panel, days later in a separate
// session, which the device has no way to observe or react to. The
// website's Conversions API event (server-side, from the actual
// payment-confirm action) is the more accurate signal for ad optimization;
// this is the best approximation available from the app itself.
Future<void> logVerificationFeePaid(double amount) async {
  try {
    await FacebookAppEvents().logPurchase(amount: amount, currency: 'PKR');
  } catch (_) {
    // Never block the payment flow over an ad-attribution signal.
  }
}
