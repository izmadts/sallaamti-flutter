import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';

class AppNotification {
  final String id;
  final String? type;
  final String? message;
  final String? url;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    this.type,
    this.message,
    this.url,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String?,
        message: json['message'] as String?,
        url: json['url'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class NotificationRepository {
  final ApiClient _client;
  NotificationRepository(this._client);

  Future<({List<AppNotification> notifications, int unreadCount})> index() async {
    final data = await _client.get('/notifications');
    return (
      notifications: (data['notifications'] as List).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      unreadCount: data['unread_count'] as int? ?? 0,
    );
  }

  Future<int> unreadCount() async {
    final data = await _client.get('/notifications/unread-count');
    return data['unread_count'] as int? ?? 0;
  }

  Future<void> markRead(String id) => _client.post('/notifications/$id/read');

  Future<void> markAllRead() => _client.post('/notifications/read-all');
}

final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(apiClientProvider)));

// A single fetch only reflects reality at the moment the dashboard happened
// to mount — a push arriving while the member is just sitting on a screen
// would otherwise leave the badge stale until some unrelated navigation
// re-triggered it. Polling keeps it honest without needing to wire the FCM
// foreground handler (a plain top-level function, outside the widget tree)
// into Riverpod's provider graph just for this.
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final repo = ref.watch(notificationRepositoryProvider);
  while (true) {
    try {
      yield await repo.unreadCount();
    } catch (_) {
      // Transient network hiccup — keep the last-known count on screen and
      // just try again next tick rather than surfacing an error state for
      // what's a minor badge number.
    }
    await Future.delayed(const Duration(seconds: 20));
  }
});

final notificationsListProvider = FutureProvider.autoDispose((ref) => ref.watch(notificationRepositoryProvider).index());
