// Mirrors Api\V1\NikahInterestController::interestPayload().
class NikahInterest {
  final int interestId;
  final String status;
  final DateTime createdAt;
  // true when the other side's profile row no longer resolves (orphaned
  // data) — `profile` is null in this case. Rendered as a disabled "no
  // longer available" card instead of crashing on a null profileId.
  final bool unavailable;
  // true when a block exists between the two profiles, in either
  // direction — deliberately not distinguished (who blocked whom) to
  // match the same privacy choice made everywhere else blocks surface.
  final bool blocked;
  final int? profileId;
  final String? name;
  final int? age;
  final String? city;
  final String? profession;
  final String? photoUrl;

  NikahInterest({
    required this.interestId,
    required this.status,
    required this.createdAt,
    required this.unavailable,
    required this.blocked,
    this.profileId,
    this.name,
    this.age,
    this.city,
    this.profession,
    this.photoUrl,
  });

  // Declined, blocked, or pointing at a profile that no longer exists —
  // none of these should be a normal, tappable card: nothing useful to
  // open, and tapping a blocked profile used to dead-end on the browse
  // 404. The list screen uses this to gray the card out and disable tap.
  bool get isInactive => unavailable || blocked || status == 'declined';

  factory NikahInterest.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'] as Map?;
    final profile = profileJson != null ? Map<String, dynamic>.from(profileJson) : null;
    return NikahInterest(
      interestId: json['interest_id'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      unavailable: json['unavailable'] as bool? ?? false,
      blocked: json['blocked'] as bool? ?? false,
      profileId: profile?['id'] as int?,
      name: profile?['name'] as String?,
      age: profile?['age'] as int?,
      city: profile?['city'] as String?,
      profession: profile?['profession'] as String?,
      photoUrl: profile?['photo_url'] as String?,
    );
  }
}
