import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  const LoginRequested(this.email, this.password);
  @override
  List<Object> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String username;
  final String fullName;
  final String email;
  final String password;
  final String phone;
  const RegisterRequested(this.username, this.fullName, this.email, this.password, {this.phone = ''});
  @override
  List<Object> get props => [username, fullName, email, password, phone];
}

class ForgotPasswordRequested extends AuthEvent {
  final String email;
  const ForgotPasswordRequested(this.email);
  @override
  List<Object> get props => [email];
}

class VerifyOtpRequested extends AuthEvent {
  final String email;
  final String otpCode;
  const VerifyOtpRequested(this.email, this.otpCode);
  @override
  List<Object> get props => [email, otpCode];
}

class CheckAuthStatus extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

class ResetPasswordRequested extends AuthEvent {
  final String email;
  final String otpCode;
  final String newPassword;
  const ResetPasswordRequested(this.email, this.otpCode, this.newPassword);
  @override
  List<Object> get props => [email, otpCode, newPassword];
}
