import '../../../../core/errors/failure.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository repository;
  VerifyOtpUseCase(this.repository);
  Future<Result<void, Failure>> call(String email, String otpCode) => repository.verifyOtp(email, otpCode);
}
