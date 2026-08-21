import '../../../core/api/api_client.dart';
import '../domain/app_user.dart';

class AuthResult {
  final AppUser user;
  final String token;
  AuthResult({required this.user, required this.token});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
        token: json['token'] as String,
      );
}

class AuthRepository {
  final ApiClient _client;
  AuthRepository(this._client);

  Future<AuthResult> register({
    required String name,
    String? email,
    String? phone,
    required String password,
  }) async {
    final data = await _client.post('/auth/register', data: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': password,
    });
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> login({required String login, required String password}) async {
    final data = await _client.post('/auth/login', data: {'login': login, 'password': password});
    return AuthResult.fromJson(data);
  }

  Future<String> requestOtp({required String phone, required String email, String? name}) async {
    final data = await _client.post('/auth/otp/request', data: {
      'phone': phone,
      'email': email,
      'name': name,
    });
    return data['purpose'] as String;
  }

  Future<AuthResult> verifyOtp({
    required String phone,
    required String code,
    required String email,
    String? name,
  }) async {
    final data = await _client.post('/auth/otp/verify', data: {
      'phone': phone,
      'code': code,
      'email': email,
      'name': name,
    });
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> socialGoogle(String idToken) async {
    final data = await _client.post('/auth/social/google', data: {'id_token': idToken});
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> socialFacebook(String accessToken) async {
    final data = await _client.post('/auth/social/facebook', data: {'access_token': accessToken});
    return AuthResult.fromJson(data);
  }

  Future<void> logout() => _client.post('/auth/logout');

  Future<AppUser> me() async {
    final data = await _client.get('/auth/me');
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }
}
