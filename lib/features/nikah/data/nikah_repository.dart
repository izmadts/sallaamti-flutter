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

class NikahContactInfo {
  final String? guardianName;
  final String? guardianRelation;
  final String? guardianContact;
  NikahContactInfo({this.guardianName, this.guardianRelation, this.guardianContact});

  factory NikahContactInfo.fromJson(Map<String, dynamic> json) => NikahContactInfo(
        guardianName: json['guardian_name'] as String?,
        guardianRelation: json['guardian_relation'] as String?,
        guardianContact: json['guardian_contact'] as String?,
      );
}

class NikahProfileDetail {
  final NikahCard profile;
  final int matchPercentage;
  final String? interestStatus;
  final bool isMineSent;
  final bool isSaved;
  final int? interestId;
  final bool hasAcceptedInterest;
  final NikahContactInfo? contact;
  NikahProfileDetail({
    required this.profile,
    required this.matchPercentage,
    this.interestStatus,
    required this.isMineSent,
    required this.isSaved,
    this.interestId,
    this.hasAcceptedInterest = false,
    this.contact,
  });
}

class NikahMessage {
  final int id;
  final String message;
  final bool isMine;
  final String? senderName;
  final DateTime createdAt;
  NikahMessage({required this.id, required this.message, required this.isMine, this.senderName, required this.createdAt});

  factory NikahMessage.fromJson(Map<String, dynamic> json) => NikahMessage(
        id: json['id'] as int,
        message: json['message'] as String,
        isMine: json['is_mine'] as bool? ?? false,
        senderName: json['sender_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class NikahBlockedProfile {
  final int blockId;
  final int? profileId;
  final String? name;
  final String? city;
  final int? age;
  NikahBlockedProfile({required this.blockId, this.profileId, this.name, this.city, this.age});

  factory NikahBlockedProfile.fromJson(Map<String, dynamic> json) => NikahBlockedProfile(
        blockId: json['block_id'] as int,
        profileId: json['profile_id'] as int?,
        name: json['name'] as String?,
        city: json['city'] as String?,
        age: json['age'] as int?,
      );
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
      interestId: data['interest_id'] as int?,
      hasAcceptedInterest: data['has_accepted_interest'] as bool? ?? false,
      contact: data['contact'] != null ? NikahContactInfo.fromJson(Map<String, dynamic>.from(data['contact'] as Map)) : null,
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

  Future<List<NikahCard>> savedProfiles() async {
    final data = await _client.get('/nikah/saved');
    return (data['profiles'] as List).map((e) => NikahCard.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<NikahMessage>> listMessages(int interestId) async {
    final data = await _client.get('/nikah/interests/$interestId/messages');
    return (data['messages'] as List).map((e) => NikahMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<NikahMessage> sendMessage(int interestId, String message) async {
    final data = await _client.post('/nikah/interests/$interestId/messages', data: {'message': message});
    return NikahMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
  }

  Future<void> blockProfile(int profileId) => _client.post('/nikah/block/$profileId');
  Future<void> unblockProfile(int blockId) => _client.delete('/nikah/block/$blockId');

  Future<List<NikahBlockedProfile>> blockedList() async {
    final data = await _client.get('/nikah/blocked');
    return (data['blocked'] as List).map((e) => NikahBlockedProfile.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> reportProfile(int profileId, {required String reason, String? details, int? interestId}) =>
      _client.post('/nikah/report/$profileId', data: {
        'reason': reason,
        'details': details,
        'nikah_interest_id': interestId,
      });

  Future<bool> toggleActive() async {
    final data = await _client.post('/nikah/toggle-active');
    return data['is_active'] as bool? ?? true;
  }
}
