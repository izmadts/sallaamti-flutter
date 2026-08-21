// Mirrors Api\V1\NikahInterestController::interestPayload().
class NikahInterest {
  final int interestId;
  final String status;
  final DateTime createdAt;
  final int profileId;
  final String? name;
  final int? age;
  final String? city;
  final String? profession;
  final String? photoUrl;

  NikahInterest({
    required this.interestId,
    required this.status,
    required this.createdAt,
    required this.profileId,
    this.name,
    this.age,
    this.city,
    this.profession,
    this.photoUrl,
  });

  factory NikahInterest.fromJson(Map<String, dynamic> json) {
    final profile = Map<String, dynamic>.from(json['profile'] as Map);
    return NikahInterest(
      interestId: json['interest_id'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      profileId: profile['id'] as int,
      name: profile['name'] as String?,
      age: profile['age'] as int?,
      city: profile['city'] as String?,
      profession: profile['profession'] as String?,
      photoUrl: profile['photo_url'] as String?,
    );
  }
}
