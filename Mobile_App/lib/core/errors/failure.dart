import 'package:equatable/equatable.dart';

sealed class Result<S, F> extends Equatable {
  const Result();

  @override
  List<Object?> get props => [];

  T fold<T>(T Function(S success) onSuccess, T Function(F failure) onFailure) {
    if (this is Success<S, F>) {
      return onSuccess((this as Success<S, F>).value);
    } else if (this is FailureResult<S, F>) {
      return onFailure((this as FailureResult<S, F>).failure);
    }
    throw StateError('Unexpected subclass of Result: $this');
  }
}

class Success<S, F> extends Result<S, F> {
  final S value;

  const Success(this.value);

  @override
  List<Object?> get props => [value];
}

class FailureResult<S, F> extends Result<S, F> {
  final F failure;

  const FailureResult(this.failure);

  @override
  List<Object?> get props => [failure];
}

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

class UnknownFailure extends Failure {
  const UnknownFailure({required super.message, super.code});
}
