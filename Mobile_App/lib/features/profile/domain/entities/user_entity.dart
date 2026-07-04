import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String profileImageUrl;
  final String username;
  final String specialization;
  final String hospitalName;
  final int appointmentsCount;
  final int prescriptionsCount;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.profileImageUrl,
    required this.username,
    required this.specialization,
    required this.hospitalName,
    required this.appointmentsCount,
    required this.prescriptionsCount,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phoneNumber,
        profileImageUrl,
        username,
        specialization,
        hospitalName,
        appointmentsCount,
        prescriptionsCount,
      ];
}
