import '../../../../core/errors/failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_entity.dart';

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);
  Future<Result<AuthEntity, Failure>> call(String email, String password) => repository.login(email, password);
}
