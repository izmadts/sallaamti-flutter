import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/push/push_notification_service.dart';
import '../../../core/storage/secure_store.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;

  const AuthState({required this.status, this.user});

  const AuthState.checking() : this(status: AuthStatus.checking);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.authenticated(AppUser user) : this(status: AuthStatus.authenticated, user: user);
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider), ref.watch(pushNotificationServiceProvider)),
);

// Every method either lands on AuthStatus.authenticated with a fresh user,
// or throws an ApiException the calling screen catches to show inline —
// this notifier never swallows a failure into a generic "unauthenticated"
// state, so a failed login doesn't silently look like a logged-out app.
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final PushNotificationService _push;

  AuthController(this._repository, this._push) : super(const AuthState.checking()) {
    _restoreSession();
  }

  // Fire-and-forget — a device-token registration failure (permission
  // denied, Firebase not reachable, etc.) must never block sign-in.
  void _registerPushSafely() {
    _push.registerThisDevice().catchError((Object e, StackTrace st) {
      if (kDebugMode) debugPrint('Push registration failed: $e');
    });
  }

  Future<void> _restoreSession() async {
    final token = await SecureStore.readToken();
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final user = await _repository.me();
      state = AuthState.authenticated(user);
      _registerPushSafely();
    } on ApiException {
      await SecureStore.clearToken();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> register({required String name, String? email, String? phone, required String password}) async {
    final result = await _repository.register(name: name, email: email, phone: phone, password: password);
    await SecureStore.saveToken(result.token);
    state = AuthState.authenticated(result.user);
    _registerPushSafely();
  }

  Future<void> login({required String login, required String password}) async {
    final result = await _repository.login(login: login, password: password);
    await SecureStore.saveToken(result.token);
    state = AuthState.authenticated(result.user);
    _registerPushSafely();
  }

  Future<String> requestOtp({required String phone, required String email, String? name}) {
    return _repository.requestOtp(phone: phone, email: email, name: name);
  }

  Future<void> verifyOtp({required String phone, required String code, required String email, String? name}) async {
    final result = await _repository.verifyOtp(phone: phone, code: code, email: email, name: name);
    await SecureStore.saveToken(result.token);
    state = AuthState.authenticated(result.user);
    _registerPushSafely();
  }

  Future<void> socialGoogle(String idToken) async {
    final result = await _repository.socialGoogle(idToken);
    await SecureStore.saveToken(result.token);
    state = AuthState.authenticated(result.user);
    _registerPushSafely();
  }

  Future<void> socialFacebook(String accessToken) async {
    final result = await _repository.socialFacebook(accessToken);
    await SecureStore.saveToken(result.token);
    state = AuthState.authenticated(result.user);
    _registerPushSafely();
  }

  // Pushes a freshly-fetched user (after a profile/module update) back into
  // the shared auth state, so the dashboard and every other screen reading
  // authControllerProvider reflect the change immediately — no re-login
  // needed just because the avatar or module visibility changed.
  void setUser(AppUser user) {
    state = AuthState.authenticated(user);
  }

  Future<void> logout() async {
    // Best-effort, and must happen before the token is cleared below — the
    // unregister call needs to still be authenticated to reach this device's
    // own device-token row.
    try {
      await _push.unregisterThisDevice();
    } catch (_) {
      // Not fatal — a stale token server-side just means a future send to
      // it fails silently on Firebase's end.
    }
    try {
      await _repository.logout();
    } on ApiException {
      // Token may already be invalid server-side — proceed to clear the
      // local session regardless, since the user's intent is to be logged
      // out either way.
    }
    await SecureStore.clearToken();
    state = const AuthState.unauthenticated();
  }
}
