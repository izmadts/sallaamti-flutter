import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// One shared secure-storage box for the small bits of session state that
// need to survive an app restart: the Sanctum bearer token and the user's
// chosen language. Deliberately not a full key-value cache — anything else
// belongs in Riverpod state, refetched from the API when needed.
class SecureStore {
  SecureStore._();
  static final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _localeKey = 'locale_code';

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<String?> readToken() => _storage.read(key: _tokenKey);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<void> saveLocale(String code) => _storage.write(key: _localeKey, value: code);
  static Future<String?> readLocale() => _storage.read(key: _localeKey);
}
