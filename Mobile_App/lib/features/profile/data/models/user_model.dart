import '../../domain/entities/user_entity.dart';

/// Base host of the server (without /api suffix) used to resolve relative image paths.
const _serverHost = 'https://clinicai.runasp.net';

/// Converts a relative image path returned by the server into a full URL.
/// e.g. "/uploads/profiles/xxx.jpg"  →  "https://clinicai.runasp.net/uploads/profiles/xxx.jpg"
String _resolveImageUrl(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  // relative path – prepend server host
  return '$_serverHost${raw.startsWith('/') ? '' : '/'}$raw';
}

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.phoneNumber,
    required super.profileImageUrl,
    required super.username,
    required super.specialization,
    required super.hospitalName,
    required super.appointmentsCount,
    required super.prescriptionsCount,
  });

  static String _displayHospital(String? raw) {
    if (raw == null || raw.isEmpty) return 'Private';
    final trimmed = raw.trim();
    if (trimmed == 'None' || trimmed == 'null') return 'Private';
    return trimmed;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawImage = json['profileImageUrl']?.toString() ??
        json['imageUrl']?.toString() ??
        json['ImageUrl']?.toString() ??
        '';
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? json['emailAddress']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone']?.toString() ?? '',
      profileImageUrl: _resolveImageUrl(rawImage),
      username: json['username']?.toString() ?? json['userName']?.toString() ?? '',
      specialization: json['specialization']?.toString() ?? '',
      hospitalName: _displayHospital(json['hospitalName']?.toString()),
      appointmentsCount: int.tryParse(json['appointmentsCount']?.toString() ?? '') ?? 0,
      prescriptionsCount: int.tryParse(json['prescriptionsCount']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'username': username,
      'specialization': specialization,
      'hospitalName': hospitalName,
      'appointmentsCount': appointmentsCount,
      'prescriptionsCount': prescriptionsCount,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'fullName': name,
      'phone': phoneNumber,
      'specialization': specialization,
    };
  }
}
