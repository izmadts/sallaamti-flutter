import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/module_themes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/notification_repository.dart';

// A real notification inbox, not a decorative placeholder — every
// member-relevant Nikah event (interest received/accepted/declined,
// payment confirmed, profile verified/rejected) already writes here via
// Laravel's `database` notification channel; this just surfaces that same
// history the FCM pushes come from.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  // Quran Live's own notification `data.type`s (see the app's FCM handling —
  // these arrive from Api\V1's QuranFeeReminder/QuranClassReminder/
  // QuranClassAssigned/QuranLivePaymentConfirmed/QuranClassLinkPosted
  // notifications) all land on My Class; everything else here is Nikah, the
  // only module this inbox originally covered.
  static const _quranLiveTypes = {
    'quran_fee_due',
    'quran_class_today',
    'quran_class_assigned',
    'quran_payment_confirmed',
    'quran_class_link_posted',
  };

  String? _resolveInAppRoute(String? url, String? type) {
    if (_quranLiveTypes.contains(type)) return '/quran-live/my-class';
    // The web route names all start with 'quran-live.', but the URL PATHS
    // themselves don't consistently — /my-quran-class (my-class) vs
    // /quran-live/{course}/... (fee reminder) — so 'quran' alone is the
    // substring that's actually present in every one of them. No other
    // module's routes contain that word.
    if (url != null && Uri.tryParse(url)?.path.contains('quran') == true) return '/quran-live/my-class';

    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.path.contains('interests')) return '/nikah/interests';
    if (uri.path.contains('browse')) return '/nikah/browse';
    if (uri.path.contains('edit')) return '/nikah/wizard/step1';
    return '/nikah';
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'interest_received' => Icons.mail_outline,
      'interest_accepted' => Icons.favorite,
      'interest_declined' => Icons.heart_broken_outlined,
      'payment_confirmed' => Icons.payments_outlined,
      'profile_verified' => Icons.verified_outlined,
      'profile_rejected' => Icons.error_outline,
      'quran_fee_due' => Icons.payments_outlined,
      'quran_class_today' => Icons.calendar_today_outlined,
      'quran_class_assigned' => Icons.groups_outlined,
      'quran_payment_confirmed' => Icons.check_circle_outline,
      'quran_class_link_posted' => Icons.videocam_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final primary = ModuleThemes.seedFor('nikah');
    final async = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsListProvider);
            },
            child: Text(l10n.notificationsMarkAllRead, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsListProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text(l10n.errorGeneric)),
            ],
          ),
          data: (data) {
            if (data.notifications.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(l10n.notificationsEmpty, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = data.notifications[index];
                return Card(
                  color: n.read ? null : primary.withValues(alpha: 0.06),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.read ? Colors.grey.shade100 : primary.withValues(alpha: 0.12),
                      child: Icon(_iconFor(n.type), color: n.read ? Colors.grey.shade600 : primary, size: 20),
                    ),
                    title: Text(n.message ?? '', style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                    subtitle: Text(DateFormat('d MMM, h:mm a').format(n.createdAt.toLocal())),
                    trailing: n.read ? null : Icon(Icons.circle, size: 8, color: primary),
                    onTap: () async {
                      if (!n.read) {
                        await ref.read(notificationRepositoryProvider).markRead(n.id);
                        ref.invalidate(notificationsListProvider);
                      }
                      final route = _resolveInAppRoute(n.url, n.type);
                      if (route != null && context.mounted) context.push(route);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
