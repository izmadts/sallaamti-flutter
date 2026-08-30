import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';
import '../domain/nikah_profile.dart';
import 'nikah_repository.dart';

class NikahCounselor {
  final int id;
  final String name;
  final String? avatar;
  final String? bio;
  final String? tier;
  final String? city;
  final String? gender;

  NikahCounselor({required this.id, required this.name, this.avatar, this.bio, this.tier, this.city, this.gender});

  factory NikahCounselor.fromJson(Map<String, dynamic> json) => NikahCounselor(
        id: json['id'] as int,
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
        bio: json['bio'] as String?,
        tier: json['tier'] as String?,
        city: json['city'] as String?,
        gender: json['gender'] as String?,
      );
}

class NikahCounselorSummary {
  final int id;
  final String name;
  final String? avatar;
  NikahCounselorSummary({required this.id, required this.name, this.avatar});

  factory NikahCounselorSummary.fromJson(Map<String, dynamic> json) => NikahCounselorSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
      );
}

// A member's Lead once they've hired a counselor — null everywhere else
// (self-service only), so screens can tell "hasn't hired anyone" apart
// from "hired but not yet paid" cleanly.
class HiredLead {
  final int id;
  final NikahCounselorSummary? counselor;
  final int? nikahPackageId;
  final String? packagePaymentStatus;
  final String? packagePaymentRejectionReason;

  HiredLead({
    required this.id,
    this.counselor,
    this.nikahPackageId,
    this.packagePaymentStatus,
    this.packagePaymentRejectionReason,
  });

  factory HiredLead.fromJson(Map<String, dynamic> json) => HiredLead(
        id: json['id'] as int,
        counselor: json['counselor'] != null ? NikahCounselorSummary.fromJson(Map<String, dynamic>.from(json['counselor'] as Map)) : null,
        nikahPackageId: json['nikah_package_id'] as int?,
        packagePaymentStatus: json['package_payment_status'] as String?,
        packagePaymentRejectionReason: json['package_payment_rejection_reason'] as String?,
      );
}

class CounselorPackage {
  final int id;
  final String name;
  final String? tagline;
  final String? description;
  final List<dynamic> features;
  final num price;
  final String? currency;
  final int? durationDays;
  final int? proposalLimit;

  CounselorPackage({
    required this.id,
    required this.name,
    this.tagline,
    this.description,
    required this.features,
    required this.price,
    this.currency,
    this.durationDays,
    this.proposalLimit,
  });

  factory CounselorPackage.fromJson(Map<String, dynamic> json) => CounselorPackage(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String,
        tagline: json['tagline'] as String?,
        description: json['description'] as String?,
        features: _asList(json['features']),
        price: num.tryParse(json['price'].toString()) ?? 0,
        currency: json['currency'] as String?,
        durationDays: _asInt(json['duration_days']),
        proposalLimit: _asInt(json['proposal_limit']),
      );

  // A JSON array with non-sequential PHP keys serializes as a JSON object,
  // not an array — 'as List' throws on that shape. Falls back to the map's
  // values, or [] for anything else.
  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.values.toList();
    return [];
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class CounselorPackagesResult {
  final List<CounselorPackage> packages;
  final NikahPaymentInstructions paymentInstructions;
  CounselorPackagesResult({required this.packages, required this.paymentInstructions});
}

class NikahHireRepository {
  final ApiClient _client;
  NikahHireRepository(this._client);

  Future<List<NikahCounselor>> counselors({String? city, String? gender}) async {
    final data = await _client.get('/nikah/counselors', query: {
      if (city != null && city.isNotEmpty) 'city': city,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
    });
    return (data['counselors'] as List).map((e) => NikahCounselor.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<HiredLead> hire(int counselorId) async {
    final data = await _client.post('/nikah/hire-counselor', data: {'counselor_id': counselorId});
    return HiredLead.fromJson(Map<String, dynamic>.from(data['lead'] as Map));
  }

  Future<HiredLead?> myLead() async {
    final data = await _client.get('/nikah/my-lead');
    if (data['lead'] == null) return null;
    return HiredLead.fromJson(Map<String, dynamic>.from(data['lead'] as Map));
  }

  Future<CounselorPackagesResult> packages() async {
    final data = await _client.get('/nikah/lead-packages');
    return CounselorPackagesResult(
      packages: (data['packages'] as List).map((e) => CounselorPackage.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      paymentInstructions: NikahPaymentInstructions.fromJson(
        Map<String, dynamic>.from((data['payment_instructions'] as Map?) ?? const {}),
      ),
    );
  }

  Future<HiredLead> submitPackage({
    required int packageId,
    required String paymentMethod,
    String? paymentReference,
    required File screenshot,
  }) async {
    final data = await _client.postMultipart('/nikah/lead-package', fields: {
      'nikah_package_id': packageId,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
    }, files: {
      'payment_screenshot': screenshot,
    });
    return HiredLead.fromJson(Map<String, dynamic>.from(data['lead'] as Map));
  }

  Future<List<NikahMessage>> listLeadMessages(int leadId) async {
    final data = await _client.get('/leads/$leadId/messages');
    return (data['messages'] as List).map((e) => NikahMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<NikahMessage> sendLeadMessage(int leadId, String message) async {
    final data = await _client.post('/leads/$leadId/messages', data: {'message': message});
    return NikahMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
  }
}

final nikahHireRepositoryProvider = Provider<NikahHireRepository>(
  (ref) => NikahHireRepository(ref.watch(apiClientProvider)),
);
