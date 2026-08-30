import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_store.dart';
import '../../auth/state/auth_controller.dart';

class VolunteerApplicationInfo {
  final int id;
  final String status;
  final String? city;
  final String? areaOfInterest;
  final String? message;
  final DateTime createdAt;
  final bool hasIdCard;

  VolunteerApplicationInfo({
    required this.id,
    required this.status,
    this.city,
    this.areaOfInterest,
    this.message,
    required this.createdAt,
    required this.hasIdCard,
  });

  factory VolunteerApplicationInfo.fromJson(Map<String, dynamic> json) => VolunteerApplicationInfo(
        id: json['id'] as int,
        status: json['status'] as String,
        city: json['city'] as String?,
        areaOfInterest: json['area_of_interest'] as String?,
        message: json['message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        hasIdCard: json['has_id_card'] as bool? ?? false,
      );
}

class VolunteerRepository {
  final ApiClient _client;
  VolunteerRepository(this._client);

  Future<VolunteerApplicationInfo?> status() async {
    final data = await _client.get('/volunteer/status');
    if (data['application'] == null) return null;
    return VolunteerApplicationInfo.fromJson(Map<String, dynamic>.from(data['application'] as Map));
  }

  Future<VolunteerApplicationInfo> apply({String? city, String? areaOfInterest, String? message}) async {
    final data = await _client.post('/volunteer/apply', data: {
      'city': city,
      'area_of_interest': areaOfInterest,
      'message': message,
    });
    return VolunteerApplicationInfo.fromJson(Map<String, dynamic>.from(data['application'] as Map));
  }

  // The ID card isn't JSON, so this bypasses ApiClient's helpers and talks
  // to Dio directly — same base URL/bearer-token pattern as everywhere
  // else, just a binary response saved to a temp file for share_plus to
  // hand off to the OS (open/save/share).
  Future<File> downloadCertificate() async {
    final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    final token = await SecureStore.readToken();

    final response = await dio.get<List<int>>(
      '/volunteer/certificate',
      options: Options(
        responseType: ResponseType.bytes,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Sallaamti-Volunteer-ID.pdf');
    await file.writeAsBytes(response.data!);
    return file;
  }
}

final volunteerRepositoryProvider = Provider((ref) => VolunteerRepository(ref.watch(apiClientProvider)));
