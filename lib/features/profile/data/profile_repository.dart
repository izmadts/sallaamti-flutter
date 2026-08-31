import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/state/auth_controller.dart';

class ProfileRepository {
  final ApiClient _client;
  ProfileRepository(this._client);

  Future<AppUser> update({
    required String name,
    String? email,
    String? phone,
    String? gender,
    String? city,
    File? avatar,
  }) async {
    final data = await _client.postMultipart('/profile', fields: {
      'name': name,
      'email': email,
      'phone': phone,
      'gender': gender,
      'city': city,
    }, files: {
      if (avatar != null) 'avatar': avatar,
    });
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<AppUser> updatePassword({
    required String currentPassword,
    required String password,
  }) async {
    final data = await _client.post('/profile/password', data: {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': password,
    });
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<AppUser> updateModules({
    required bool nikah,
    required bool quran,
    required bool counseling,
    required bool skills,
  }) async {
    final data = await _client.postMultipart('/profile/modules', fields: {
      'nikah_module_enabled': nikah,
      'quran_module_enabled': quran,
      'counseling_module_enabled': counseling,
      'skills_module_enabled': skills,
    });
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }
}

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(apiClientProvider)));
