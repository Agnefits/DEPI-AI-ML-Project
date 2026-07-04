import '../../../../core/errors/failure.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository repository;

  ResetPasswordUseCase(this.repository);

  Future<Result<void, Failure>> call(String email, String otpCode, String newPassword) {
    return repository.resetPassword(email, otpCode, newPassword);
  }
}
