// Maps a notification's `type` (from an FCM push's data payload — no `url`
// available there) or `url` (from the in-app notification list, which reads
// Laravel's `database` channel rows) to the in-app route to open on tap.
// Shared by notifications_screen.dart (tapping a list item) and
// push_notification_service.dart (tapping a system-tray push) so the two
// paths can never resolve the same notification two different ways.
library;

// Quran Live's own notification `data.type`s (see QuranFeeReminder/
// QuranClassReminder/QuranClassAssigned/QuranLivePaymentConfirmed/
// QuranClassLinkPosted notifications) all land on My Class.
const _quranLiveTypes = {
  'quran_fee_due',
  'quran_class_today',
  'quran_class_assigned',
  'quran_payment_confirmed',
  'quran_class_link_posted',
};

// Nikah types resolved directly off `type` alone — needed because an FCM
// push's data payload never carries `url`, only `type`.
const _nikahPaymentTypes = {
  'payment_confirmed',
  'payment_rejected',
  'nikah_payment_reminder',
};

String? resolveNotificationRoute({String? url, String? type}) {
  if (_quranLiveTypes.contains(type)) return '/quran-live/my-class';
  if (_nikahPaymentTypes.contains(type)) return '/nikah/payment';

  // The web route names all start with 'quran-live.', but the URL PATHS
  // themselves don't consistently — /my-quran-class (my-class) vs
  // /quran-live/{course}/... (fee reminder) — so 'quran' alone is the
  // substring that's actually present in every one of them. No other
  // module's routes contain that word.
  if (url != null && Uri.tryParse(url)?.path.contains('quran') == true) return '/quran-live/my-class';

  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  if (uri.path.contains('payment')) return '/nikah/payment';
  if (uri.path.contains('interests')) return '/nikah/interests';
  if (uri.path.contains('browse')) return '/nikah/browse';
  if (uri.path.contains('edit')) return '/nikah/wizard/step1';
  return '/nikah';
}
