import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class SupportMessage {
  final int id;
  final String body;
  final bool isMine;
  final DateTime createdAt;

  SupportMessage({required this.id, required this.body, required this.isMine, required this.createdAt});

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: _asInt(json['id']) ?? 0,
        body: json['body'] as String? ?? '',
        isMine: json['is_mine'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SupportRepository {
  final ApiClient _client;
  SupportRepository(this._client);

  Future<List<SupportMessage>> messages() async {
    final data = await _client.get('/support-messages');
    return (data['messages'] as List).map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<SupportMessage> send(String body) async {
    final data = await _client.post('/support-messages', data: {'body': body});
    return SupportMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
  }
}

final supportRepositoryProvider = Provider((ref) => SupportRepository(ref.watch(apiClientProvider)));
