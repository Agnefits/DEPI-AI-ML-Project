import '../../../../core/errors/failure.dart';
import '../../domain/repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  final AuthRepository repository;
  ForgotPasswordUseCase(this.repository);
  Future<Result<void, Failure>> call(String email) => repository.forgotPassword(email);
}
