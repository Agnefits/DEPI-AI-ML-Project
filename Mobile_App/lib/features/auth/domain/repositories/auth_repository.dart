import '../../../../core/errors/failure.dart';
import '../entities/auth_entity.dart';

abstract class AuthRepository {
  Future<Result<AuthEntity, Failure>> login(String email, String password);
  Future<Result<AuthEntity, Failure>> register(String username, String fullName, String email, String password, {String phone = ''});
  Future<Result<void, Failure>> forgotPassword(String email);
  Future<Result<void, Failure>> verifyOtp(String email, String otp);
  Future<Result<void, Failure>> resetPassword(String email, String otpCode, String newPassword);
}
