// Mirrors Api\V1\NikahBrowseController::cardPayload().
class NikahCard {
  final int id;
  final int age;
  final String? height;
  final String maritalStatus;
  final String? sect;
  final String? education;
  final String? profession;
  final String city;
  final String? country;
  final String? about;
  final String? gender;
  final Map<String, bool> trustBadges;
  final int matchPercentage;
  final bool hasSentInterest;
  final bool isSaved;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  // Only present when fetched via the detailed single-profile endpoint.
  final String? expectations;
  final String? familyType;
  final String? ethnicity;
  final String? language;
  final String? prayerFrequency;
  final String? hijabOrBeard;
  final String? diet;

  NikahCard({
    required this.id,
    required this.age,
    this.height,
    required this.maritalStatus,
    this.sect,
    this.education,
    this.profession,
    required this.city,
    this.country,
    this.about,
    this.gender,
    required this.trustBadges,
    required this.matchPercentage,
    required this.hasSentInterest,
    required this.isSaved,
    this.photoUrl,
    this.createdAt,
    this.lastActiveAt,
    this.expectations,
    this.familyType,
    this.ethnicity,
    this.language,
    this.prayerFrequency,
    this.hijabOrBeard,
    this.diet,
  });

  factory NikahCard.fromJson(Map<String, dynamic> json) => NikahCard(
        id: json['id'] as int,
        age: json['age'] as int,
        height: json['height'] as String?,
        maritalStatus: json['marital_status'] as String,
        sect: json['sect'] as String?,
        education: json['education'] as String?,
        profession: json['profession'] as String?,
        city: json['city'] as String,
        country: json['country'] as String?,
        about: json['about'] as String?,
        gender: json['gender'] as String?,
        trustBadges: Map<String, bool>.from(json['trust_badges'] as Map? ?? {}),
        matchPercentage: json['match_percentage'] as int? ?? 0,
        hasSentInterest: json['has_sent_interest'] as bool? ?? false,
        isSaved: json['is_saved'] as bool? ?? false,
        photoUrl: json['photo_url'] as String?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        lastActiveAt: json['last_active_at'] != null ? DateTime.tryParse(json['last_active_at'] as String) : null,
        expectations: json['expectations'] as String?,
        familyType: json['family_type'] as String?,
        ethnicity: json['ethnicity'] as String?,
        language: json['language'] as String?,
        prayerFrequency: json['prayer_frequency'] as String?,
        hijabOrBeard: json['hijab_or_beard'] as String?,
        diet: json['diet'] as String?,
      );
}
