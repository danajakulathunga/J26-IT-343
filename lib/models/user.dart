class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String preferredLanguage;
  final bool isGuest;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.preferredLanguage,
    this.isGuest = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? (json['name'] as String? ?? ''),
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      isGuest: json['is_guest'] as bool? ?? false,
    );
  }

  factory UserModel.guest({required String guestId, required String name}) {
    return UserModel(
      id: guestId,
      email: '',
      fullName: name,
      preferredLanguage: 'en',
      isGuest: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'preferred_language': preferredLanguage,
      'is_guest': isGuest,
    };
  }
}
