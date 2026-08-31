import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';

const counselingCategories = {
  'marital': 'Marital',
  'parenting': 'Parenting',
  'financial': 'Financial',
  'legal': 'Legal',
  'spiritual': 'Spiritual',
  'other': 'Other',
};

const counselingContactMethods = {
  'phone': 'Phone Call',
  'video': 'Video Call',
  'in_person': 'In Person',
  'chat': 'Chat',
};

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class CounselingPerson {
  final int id;
  final String name;
  final String? avatar;
  CounselingPerson({required this.id, required this.name, this.avatar});

  factory CounselingPerson.fromJson(Map<String, dynamic> json) => CounselingPerson(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
      );
}

class CounselingMeta {
  final List<String> categories;
  final List<String> contactMethods;
  final List<CounselingPerson> counselors;
  CounselingMeta({required this.categories, required this.contactMethods, required this.counselors});

  factory CounselingMeta.fromJson(Map<String, dynamic> json) => CounselingMeta(
        categories: (json['categories'] as List).map((e) => e.toString()).toList(),
        contactMethods: (json['contact_methods'] as List).map((e) => e.toString()).toList(),
        counselors: (json['counselors'] as List).map((e) => CounselingPerson.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class CounselingSlot {
  final int counselorId;
  final String? counselorName;
  final DateTime dateTime;
  final bool booked;
  CounselingSlot({required this.counselorId, this.counselorName, required this.dateTime, this.booked = false});

  factory CounselingSlot.fromJson(Map<String, dynamic> json) => CounselingSlot(
        counselorId: _asInt(json['counselor_id']) ?? 0,
        counselorName: json['counselor_name'] as String?,
        dateTime: DateTime.parse(json['datetime'] as String),
        booked: json['booked'] as bool? ?? false,
      );
}

class SupportQueryResponse {
  final int id;
  final String message;
  final CounselingPerson? responder;
  final DateTime createdAt;
  SupportQueryResponse({required this.id, required this.message, this.responder, required this.createdAt});

  factory SupportQueryResponse.fromJson(Map<String, dynamic> json) => SupportQueryResponse(
        id: _asInt(json['id']) ?? 0,
        message: json['message'] as String,
        responder: json['responder'] != null ? CounselingPerson.fromJson(Map<String, dynamic>.from(json['responder'] as Map)) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CounselingBookingInfo {
  final int id;
  final String status;
  final String? category;
  final String? subject;
  final String? description;
  final bool isAnonymous;
  final bool isUrgent;
  final String? contactMethod;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? meetingLink;
  final CounselingPerson? counselor;
  final String? notes;
  final String? cancellationReason;
  final int? memberRating;
  final String? memberFeedback;
  final DateTime createdAt;
  final List<SupportQueryResponse> responses;

  CounselingBookingInfo({
    required this.id,
    required this.status,
    this.category,
    this.subject,
    this.description,
    required this.isAnonymous,
    required this.isUrgent,
    this.contactMethod,
    required this.scheduledAt,
    required this.durationMinutes,
    this.meetingLink,
    this.counselor,
    this.notes,
    this.cancellationReason,
    this.memberRating,
    this.memberFeedback,
    required this.createdAt,
    this.responses = const [],
  });

  factory CounselingBookingInfo.fromJson(Map<String, dynamic> json) => CounselingBookingInfo(
        id: _asInt(json['id']) ?? 0,
        status: json['status'] as String,
        category: json['category'] as String?,
        subject: json['subject'] as String?,
        description: json['description'] as String?,
        isAnonymous: json['is_anonymous'] as bool? ?? false,
        isUrgent: json['is_urgent'] as bool? ?? false,
        contactMethod: json['contact_method'] as String?,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        durationMinutes: _asInt(json['duration_minutes']) ?? 30,
        meetingLink: json['meeting_link'] as String?,
        counselor: json['counselor'] != null ? CounselingPerson.fromJson(Map<String, dynamic>.from(json['counselor'] as Map)) : null,
        notes: json['notes'] as String?,
        cancellationReason: json['cancellation_reason'] as String?,
        memberRating: _asInt(json['member_rating']),
        memberFeedback: json['member_feedback'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        responses: json['responses'] != null
            ? (json['responses'] as List).map((e) => SupportQueryResponse.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            : const [],
      );
}

class CounselingRepository {
  final ApiClient _client;
  CounselingRepository(this._client);

  Future<CounselingMeta> meta() async {
    final data = await _client.get('/counseling/meta');
    return CounselingMeta.fromJson(data);
  }

  Future<List<CounselingSlot>> slots({required DateTime date, List<int>? counselorIds}) async {
    final data = await _client.get('/counseling/slots', query: {
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      if (counselorIds != null) 'counselor_ids': counselorIds.join(','),
    });
    return (data['slots'] as List).map((e) => CounselingSlot.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<CounselingBookingInfo> createBooking({
    required String category,
    required String subject,
    required String description,
    bool isAnonymous = false,
    bool isUrgent = false,
    required String contactMethod,
    int? counselorId,
    DateTime? scheduledAt,
    DateTime? preferredAt,
  }) async {
    final data = await _client.post('/counseling/bookings', data: {
      'category': category,
      'subject': subject,
      'description': description,
      'is_anonymous': isAnonymous,
      'is_urgent': isUrgent,
      'contact_method': contactMethod,
      'counselor_id': counselorId,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'preferred_at': preferredAt?.toIso8601String(),
    });
    return CounselingBookingInfo.fromJson(Map<String, dynamic>.from(data['booking'] as Map));
  }

  Future<List<CounselingBookingInfo>> myBookings() async {
    final data = await _client.get('/counseling/bookings');
    return (data['bookings'] as List).map((e) => CounselingBookingInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<CounselingBookingInfo> bookingDetail(int id) async {
    final data = await _client.get('/counseling/bookings/$id');
    return CounselingBookingInfo.fromJson(Map<String, dynamic>.from(data['booking'] as Map));
  }

  Future<CounselingBookingInfo> cancel(int id, {String? reason}) async {
    final data = await _client.post('/counseling/bookings/$id/cancel', data: {'reason': reason});
    return CounselingBookingInfo.fromJson(Map<String, dynamic>.from(data['booking'] as Map));
  }

  Future<SupportQueryResponse> reply(int id, String message) async {
    final data = await _client.post('/counseling/bookings/$id/reply', data: {'message': message});
    return SupportQueryResponse.fromJson(Map<String, dynamic>.from(data['response'] as Map));
  }

  Future<CounselingBookingInfo> rate(int id, {required int rating, String? feedback}) async {
    final data = await _client.post('/counseling/bookings/$id/rate', data: {'member_rating': rating, 'member_feedback': feedback});
    return CounselingBookingInfo.fromJson(Map<String, dynamic>.from(data['booking'] as Map));
  }
}

final counselingRepositoryProvider = Provider((ref) => CounselingRepository(ref.watch(apiClientProvider)));
