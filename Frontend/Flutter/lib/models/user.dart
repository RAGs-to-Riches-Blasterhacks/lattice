class User {
  final String id;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;
  final bool isActive;

  const User({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class AuthResponse {
  final String idToken;
  final String refreshToken;
  final String customToken;
  final User user;

  const AuthResponse({
    required this.idToken,
    required this.refreshToken,
    required this.customToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      idToken: json['id_token'] as String,
      refreshToken: json['refresh_token'] as String,
      customToken: json['custom_token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
