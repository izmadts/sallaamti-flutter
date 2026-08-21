import 'dart:io';

import '../../../core/api/api_client.dart';
import '../domain/nikah_card.dart';
import '../domain/nikah_interest.dart';
import '../domain/nikah_profile.dart';

class NikahBrowseResult {
  final List<NikahCard> profiles;
  final bool hasMore;
  final int total;
  NikahBrowseResult({required this.profiles, required this.hasMore, required this.total});
}

class NikahProfileDetail {
  final NikahCard profile;
  final int matchPercentage;
  final String? interestStatus;
  final bool isMineSent;
  final bool isSaved;
  NikahProfileDetail({
    required this.profile,
    required this.matchPercentage,
    this.interestStatus,
    required this.isMineSent,
    required this.isSaved,
  });
}

class NikahRepository {
  final ApiClient _client;
  NikahRepository(this._client);

  Future<NikahProfile?> getMyProfile() async {
    final data = await _client.get('/nikah/profile');
    if (data['has_profile'] != true) return null;
    return NikahProfile.fromJson(Map<String, dynamic>.from(data['profile'] as Map));
  }

  // One call per wizard screen — `fields` is just that screen's data,
  // `files` any images it collected. See the backend's
  // NikahProfileController::store() docblock for why this is a single
  // upsert endpoint rather than named steps.
  Future<NikahProfile> saveProfile(Map<String, dynamic> fields, {Map<String, File> files = const {}}) async {
    final data = await _client.postMultipart('/nikah/profile', fields: fields, files: files);
    return NikahProfile.fromJson(Map<String, dynamic>.from(data['profile'] as Map));
  }

  Future<void> submitProfile() => _client.post('/nikah/profile/submit');

  Future<void> submitPayment({
    required String paymentMethod,
    String? paymentReference,
    required File screenshot,
  }) =>
      _client.postMultipart('/nikah/payment', fields: {
        'payment_method': paymentMethod,
        'payment_reference': paymentReference,
      }, files: {
        'payment_screenshot': screenshot,
      });

  Future<NikahBrowseResult> browse({Map<String, String> filters = const {}, int page = 1}) async {
    final data = await _client.get('/nikah/browse', query: {...filters, 'page': page.toString()});
    final list = data['profiles'] as List;
    return NikahBrowseResult(
      profiles: list.map((e) => NikahCard.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      hasMore: data['has_more'] as bool? ?? false,
      total: data['total'] as int? ?? 0,
    );
  }

  Future<NikahProfileDetail> viewProfile(int id) async {
    final data = await _client.get('/nikah/profile/$id');
    return NikahProfileDetail(
      profile: NikahCard.fromJson(Map<String, dynamic>.from(data['profile'] as Map)),
      matchPercentage: data['match_percentage'] as int? ?? 0,
      interestStatus: data['interest_status'] as String?,
      isMineSent: data['is_mine_sent'] as bool? ?? false,
      isSaved: data['is_saved'] as bool? ?? false,
    );
  }

  Future<bool> toggleSave(int id) async {
    final data = await _client.post('/nikah/profile/$id/save');
    return data['saved'] as bool? ?? false;
  }

  Future<void> sendInterest(int profileId) => _client.post('/nikah/interests/$profileId');

  Future<({List<NikahInterest> received, List<NikahInterest> sent})> listInterests() async {
    final data = await _client.get('/nikah/interests');
    return (
      received: (data['received'] as List).map((e) => NikahInterest.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      sent: (data['sent'] as List).map((e) => NikahInterest.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }

  Future<void> acceptInterest(int interestId) => _client.post('/nikah/interests/$interestId/accept');
  Future<void> declineInterest(int interestId) => _client.post('/nikah/interests/$interestId/decline');
}
