import 'package:equatable/equatable.dart';

class AuthEntity extends Equatable {
  final String id;
  final String email;
  final String name;
  final String token;
  final String refreshToken;

  const AuthEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.token,
    this.refreshToken = '',
  });

  @override
  List<Object?> get props => [id, email, name, token, refreshToken];
}
