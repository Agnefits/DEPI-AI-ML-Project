import 'package:equatable/equatable.dart';

abstract class AppException extends Equatable implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

class ServerException extends AppException {
  const ServerException({required super.message, super.code});
}

class ValidationException extends AppException {
  const ValidationException({required super.message, super.code});
}

class AuthException extends AppException {
  const AuthException({required super.message, super.code});
}

class CacheException extends AppException {
  const CacheException({required super.message, super.code});
}

class FirebaseExceptionPlaceholder extends AppException {
  const FirebaseExceptionPlaceholder({required super.message, super.code});
}

class UnknownException extends AppException {
  const UnknownException({required super.message, super.code});
}
