import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

const _androidChannel = AndroidNotificationChannel(
  'default_channel',
  'General Notifications',
  description: 'Interest requests, payment confirmations, and profile verification updates.',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

// Android only shows a push automatically from the system tray while the
// app is backgrounded or terminated — a "notification" payload arriving
// while the app is in the foreground is delivered silently to the Dart
// side with nothing shown on screen unless something displays it. This is
// that something; called once at startup (main.dart), independent of auth.
Future<void> initLocalNotifications() async {
  await _localNotifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}

void _showForegroundNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

// Handles background/terminated-state pushes. Must be a top-level (or
// static) function — Firebase runs it in its own isolate, so it re-inits
// Firebase itself via Firebase.initializeApp() before touching anything.
// The OS displays the notification from the payload automatically in this
// state; nothing else is needed here unless we later want to react to
// data-only pushes.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

// Requests notification permission, grabs this device's FCM token, and
// keeps it registered with the backend (POST/DELETE /device-token) so a
// push can actually reach this device. Firebase.initializeApp() itself
// happens once in main() before runApp — this only runs once a member is
// signed in, since the registration endpoint requires auth.
class PushNotificationService {
  final ApiClient _client;
  PushNotificationService(this._client);

  // A fresh PushNotificationService instance is constructed per Riverpod
  // provider read (see the provider below), but the underlying
  // FirebaseMessaging.onMessage stream is process-global — a static guard
  // stops registerThisDevice() (called on every login and session-restore)
  // from stacking a duplicate listener and showing each push twice.
  static bool _foregroundListenerAttached = false;

  Future<void> registerThisDevice() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) await _sendToken(token);

    messaging.onTokenRefresh.listen(_sendToken);

    if (!_foregroundListenerAttached) {
      _foregroundListenerAttached = true;
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    }
  }

  Future<void> unregisterThisDevice() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    try {
      await _client.delete('/device-token', query: {'token': token});
    } on ApiException {
      // Best-effort on logout — the token row going stale server-side is
      // harmless (a send to it just fails silently on Firebase's end).
    }
  }

  Future<void> _sendToken(String token) async {
    try {
      await _client.post('/device-token', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } on ApiException {
      // Best-effort — this device simply won't receive pushes until the
      // next successful registration attempt (app relaunch/login).
    }
  }
}

// Constructs its own ApiClient rather than sharing auth_controller.dart's
// apiClientProvider — that file already depends on this one (to trigger
// push registration on login/logout), so sharing the provider would create
// an import cycle. ApiClient is cheap and stateless (reads the bearer token
// fresh from SecureStore per request), so a second instance is harmless.
final pushNotificationServiceProvider = Provider((ref) => PushNotificationService(ApiClient()));
