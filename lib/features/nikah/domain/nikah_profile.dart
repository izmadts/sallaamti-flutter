// Mirrors Api\V1\NikahProfileController::profilePayload() on the backend.
class NikahProfile {
  final int id;
  final String publicToken;
  final int age;
  final String? height;
  final String maritalStatus;
  final bool? openToPolygamy;
  final String? sect;
  final String? caste;
  final String? prayerFrequency;
  final String? hijabOrBeard;
  final String? smokes;
  final String? diet;
  final String? education;
  final String? profession;
  final String city;
  final String? state;
  final String? country;
  final String? ethnicity;
  final String? language;
  final String? familyType;
  final String guardianName;
  final String guardianContact;
  final String? guardianRelation;
  final String? about;
  final String? expectations;
  final bool hasPhoto;
  final bool allowPhotoSharing;
  final bool hasCnicNumber;
  final String verificationStatus;
  final String? rejectionReason;
  final String visibility;
  final bool isActive;
  final String paymentStatus;
  final String? paymentAmount;
  final NikahPaymentInstructions paymentInstructions;
  final int? prefMinAge;
  final int? prefMaxAge;
  final String? prefCity;
  final String? prefSect;
  final String? prefEducation;
  final String? prefMaritalStatus;
  final int completenessPercentage;
  final bool canBrowse;

  NikahProfile({
    required this.id,
    required this.publicToken,
    required this.age,
    this.height,
    required this.maritalStatus,
    this.openToPolygamy,
    this.sect,
    this.caste,
    this.prayerFrequency,
    this.hijabOrBeard,
    this.smokes,
    this.diet,
    this.education,
    this.profession,
    required this.city,
    this.state,
    this.country,
    this.ethnicity,
    this.language,
    this.familyType,
    required this.guardianName,
    required this.guardianContact,
    this.guardianRelation,
    this.about,
    this.expectations,
    required this.hasPhoto,
    required this.allowPhotoSharing,
    required this.hasCnicNumber,
    required this.verificationStatus,
    this.rejectionReason,
    required this.visibility,
    required this.isActive,
    required this.paymentStatus,
    this.paymentAmount,
    required this.paymentInstructions,
    this.prefMinAge,
    this.prefMaxAge,
    this.prefCity,
    this.prefSect,
    this.prefEducation,
    this.prefMaritalStatus,
    required this.completenessPercentage,
    required this.canBrowse,
  });

  factory NikahProfile.fromJson(Map<String, dynamic> json) => NikahProfile(
        id: json['id'] as int,
        publicToken: json['public_token'] as String,
        age: json['age'] as int,
        height: json['height'] as String?,
        maritalStatus: json['marital_status'] as String,
        openToPolygamy: json['open_to_polygamy'] as bool?,
        sect: json['sect'] as String?,
        caste: json['caste'] as String?,
        prayerFrequency: json['prayer_frequency'] as String?,
        hijabOrBeard: json['hijab_or_beard'] as String?,
        smokes: json['smokes'] as String?,
        diet: json['diet'] as String?,
        education: json['education'] as String?,
        profession: json['profession'] as String?,
        city: json['city'] as String,
        state: json['state'] as String?,
        country: json['country'] as String?,
        ethnicity: json['ethnicity'] as String?,
        language: json['language'] as String?,
        familyType: json['family_type'] as String?,
        guardianName: json['guardian_name'] as String,
        guardianContact: json['guardian_contact'] as String,
        guardianRelation: json['guardian_relation'] as String?,
        about: json['about'] as String?,
        expectations: json['expectations'] as String?,
        hasPhoto: json['has_photo'] as bool? ?? false,
        allowPhotoSharing: json['allow_photo_sharing'] as bool? ?? true,
        hasCnicNumber: json['has_cnic_number'] as bool? ?? false,
        verificationStatus: json['verification_status'] as String,
        rejectionReason: json['rejection_reason'] as String?,
        visibility: json['visibility'] as String,
        isActive: json['is_active'] as bool? ?? true,
        paymentStatus: json['payment_status'] as String,
        paymentAmount: json['payment_amount']?.toString(),
        paymentInstructions: NikahPaymentInstructions.fromJson(
          json['payment_instructions'] as Map<String, dynamic>? ?? const {},
        ),
        prefMinAge: json['pref_min_age'] as int?,
        prefMaxAge: json['pref_max_age'] as int?,
        prefCity: json['pref_city'] as String?,
        prefSect: json['pref_sect'] as String?,
        prefEducation: json['pref_education'] as String?,
        prefMaritalStatus: json['pref_marital_status'] as String?,
        completenessPercentage: json['completeness_percentage'] as int? ?? 0,
        canBrowse: json['can_browse'] as bool? ?? false,
      );

  // CNIC front/back photo requirement retired — the wizard's own step-level
  // validation already enforces CNIC number and photo being filled in
  // before reaching review, so there's nothing left to gate here beyond
  // that having actually happened.
  bool get isComplete => hasCnicNumber && hasPhoto;
}

// Wherever to actually send the verification fee — configured by admins in
// Settings, same source of truth the web payment page reads from. Any of
// these can be null if that method hasn't been configured yet.
class NikahPaymentInstructions {
  final String? jazzcashNumber;
  final String? jazzcashAccountTitle;
  final String? easypaisaNumber;
  final String? bankName;
  final String? bankAccountTitle;
  final String? bankAccountNumber;
  final String? bankAccountIban;

  const NikahPaymentInstructions({
    this.jazzcashNumber,
    this.jazzcashAccountTitle,
    this.easypaisaNumber,
    this.bankName,
    this.bankAccountTitle,
    this.bankAccountNumber,
    this.bankAccountIban,
  });

  factory NikahPaymentInstructions.fromJson(Map<String, dynamic> json) => NikahPaymentInstructions(
        jazzcashNumber: json['jazzcash_number'] as String?,
        jazzcashAccountTitle: json['jazzcash_account_title'] as String?,
        easypaisaNumber: json['easypaisa_number'] as String?,
        bankName: json['bank_name'] as String?,
        bankAccountTitle: json['bank_account_title'] as String?,
        bankAccountNumber: json['bank_account_number'] as String?,
        bankAccountIban: json['bank_account_iban'] as String?,
      );

  bool get hasJazzcash => jazzcashNumber != null && jazzcashNumber!.isNotEmpty;
  bool get hasEasypaisa => easypaisaNumber != null && easypaisaNumber!.isNotEmpty;
  bool get hasBankTransfer => bankName != null && bankName!.isNotEmpty;
  bool get hasAnyMethod => hasJazzcash || hasEasypaisa || hasBankTransfer;
}
