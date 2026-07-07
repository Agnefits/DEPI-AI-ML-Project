import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String status;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.status,
  });

  @override
  List<Object?> get props => [id, name, email, role, phone, status];
}
