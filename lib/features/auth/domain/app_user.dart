// Mirrors App\Http\Resources\Api\UserResource on the backend — keep the two
// in sync by hand; there are few enough fields that a shared schema tool
// would be more overhead than it saves right now.
class AppUser {
  final int id;
  final String name;
  final String? username;
  final String? email;
  final String? phone;
  final String? gender;
  final String? city;
  final String avatarUrl;
  final List<String> roles;
  final Map<String, bool> modules;
  final bool hasNikahProfile;

  AppUser({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.phone,
    this.gender,
    this.city,
    required this.avatarUrl,
    required this.roles,
    required this.modules,
    required this.hasNikahProfile,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        username: json['username'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        gender: json['gender'] as String?,
        city: json['city'] as String?,
        avatarUrl: json['avatar_url'] as String? ?? '',
        roles: (json['roles'] as List? ?? []).map((e) => e.toString()).toList(),
        modules: Map<String, bool>.from(json['modules'] as Map? ?? {}),
        hasNikahProfile: json['has_nikah_profile'] as bool? ?? false,
      );
}
