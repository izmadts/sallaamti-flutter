import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';

class DonationPurpose {
  final String value;
  final String label;
  DonationPurpose({required this.value, required this.label});

  factory DonationPurpose.fromJson(Map<String, dynamic> json) => DonationPurpose(
        value: json['value'] as String,
        label: json['label'] as String,
      );
}

class DonationPaymentInstructions {
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountIban;
  final String? accountTitle;

  const DonationPaymentInstructions({this.bankName, this.bankAccountNumber, this.bankAccountIban, this.accountTitle});

  factory DonationPaymentInstructions.fromJson(Map<String, dynamic> json) => DonationPaymentInstructions(
        bankName: json['bank_name'] as String?,
        bankAccountNumber: json['bank_account_number'] as String?,
        bankAccountIban: json['bank_account_iban'] as String?,
        accountTitle: json['account_title'] as String?,
      );

  bool get hasAnyMethod => (bankName ?? '').isNotEmpty || (bankAccountNumber ?? '').isNotEmpty;
}

class DonationMeta {
  final List<int> tiers;
  final List<DonationPurpose> purposes;
  final DonationPaymentInstructions paymentInstructions;

  DonationMeta({required this.tiers, required this.purposes, required this.paymentInstructions});

  factory DonationMeta.fromJson(Map<String, dynamic> json) => DonationMeta(
        tiers: (json['tiers'] as List).map((e) => _asInt(e) ?? 0).toList(),
        purposes: (json['purposes'] as List).map((e) => DonationPurpose.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        paymentInstructions: DonationPaymentInstructions.fromJson(
          Map<String, dynamic>.from((json['payment_instructions'] as Map?) ?? const {}),
        ),
      );
}

class DonationInfo {
  final int id;
  final String donationNumber;
  final num amount;
  final String? purpose;
  final String? message;
  final String? paymentMethod;
  final String paymentStatus;
  final String? paymentRejectionReason;
  final bool isAnonymous;
  final DateTime createdAt;

  DonationInfo({
    required this.id,
    required this.donationNumber,
    required this.amount,
    this.purpose,
    this.message,
    this.paymentMethod,
    required this.paymentStatus,
    this.paymentRejectionReason,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory DonationInfo.fromJson(Map<String, dynamic> json) => DonationInfo(
        id: _asInt(json['id']) ?? 0,
        donationNumber: json['donation_number'] as String,
        amount: num.tryParse(json['amount'].toString()) ?? 0,
        purpose: json['purpose'] as String?,
        message: json['message'] as String?,
        paymentMethod: json['payment_method'] as String?,
        paymentStatus: json['payment_status'] as String,
        paymentRejectionReason: json['payment_rejection_reason'] as String?,
        isAnonymous: json['is_anonymous'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class DonationRepository {
  final ApiClient _client;
  DonationRepository(this._client);

  Future<DonationMeta> meta() async {
    final data = await _client.get('/donations/meta');
    return DonationMeta.fromJson(data);
  }

  Future<List<DonationInfo>> index() async {
    final data = await _client.get('/donations');
    return (data['donations'] as List).map((e) => DonationInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<DonationInfo> submit({
    required num amount,
    required String paymentMethod,
    String? purpose,
    String? message,
    bool isAnonymous = false,
    File? screenshot,
  }) async {
    final data = await _client.postMultipart('/donations', fields: {
      'amount': amount,
      'payment_method': paymentMethod,
      'purpose': purpose,
      'message': message,
      'is_anonymous': isAnonymous,
    }, files: {
      if (screenshot != null) 'payment_screenshot': screenshot,
    });
    return DonationInfo.fromJson(Map<String, dynamic>.from(data['donation'] as Map));
  }
}

final donationRepositoryProvider = Provider((ref) => DonationRepository(ref.watch(apiClientProvider)));
