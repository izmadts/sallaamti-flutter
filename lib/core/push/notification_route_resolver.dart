// Maps a notification's `type`+`data` (from an FCM push's data payload — no
// `url` available there) or `url` (from the in-app notification list, which
// reads Laravel's `database` channel rows) to the in-app route to open on
// tap. Shared by notifications_screen.dart (tapping a list item) and
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

// NewProposalBatchReceived / NewConsentRequested (see Api\V1\
// NikahMatchmakingController) — both land on "My Matchmaker".
const _nikahMatchmakingTypes = {
  'proposal_batch_received',
  'consent_requested',
};

// CommunityAnnouncementPosted/CommentReceived/ReactionReceived — all land
// on the Wall, where the post/comment/reaction itself actually is (no
// comment/reaction deep-link to the specific item yet, same as web).
const _wallTypes = {
  'community_announcement',
  'wall_comment',
  'wall_reaction',
};

// [data] is the FCM push's full data payload (may be empty/absent for an
// in-app-list tap, which only ever has [url]/[type]).
String? resolveNotificationRoute({String? url, String? type, Map<String, dynamic> data = const {}}) {
  if (_quranLiveTypes.contains(type)) return '/quran-live/my-class';
  if (_nikahPaymentTypes.contains(type)) return '/nikah/payment';
  if (_nikahMatchmakingTypes.contains(type)) return '/nikah/matchmaking';
  if (_wallTypes.contains(type)) return '/wall';
  if (type == 'question_answered') return '/qa';
  if (type == 'admin_message_reply') return '/support';
  if (type == 'post_reviewed') {
    final postId = data['post_id'];
    if (postId != null) return '/community/posts/$postId';
  }

  // A push's data payload never carries url — NikahGuardianMessageReceived
  // sends interest_id alongside type for exactly this reason (see
  // app/Notifications/NikahGuardianMessageReceived.php toFcm()).
  if (type == 'guardian_message') {
    final interestId = data['interest_id'];
    if (interestId != null) return '/nikah/interests/$interestId/messages';
  }

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

  // /nikah/interests/{id}/messages (NikahGuardianMessageReceived's toArray()
  // url) used to match the generic 'interests' check below and lose the id
  // entirely, landing on the Interests list instead of the actual
  // conversation. Checked first so the more specific match wins.
  final messagesMatch = RegExp(r'/nikah/interests/(\d+)/messages').firstMatch(uri.path);
  if (messagesMatch != null) return '/nikah/interests/${messagesMatch.group(1)}/messages';

  if (uri.path.contains('interests')) return '/nikah/interests';
  if (uri.path.contains('browse')) return '/nikah/browse';
  if (uri.path.contains('edit')) return '/nikah/wizard/step1';
  return '/nikah';
}
