import '../../../../core/errors/failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_entity.dart';

class RegisterUseCase {
  final AuthRepository repository;
  RegisterUseCase(this.repository);
  Future<Result<AuthEntity, Failure>> call(String username, String fullName, String email, String password, {String phone = ''}) => repository.register(username, fullName, email, password, phone: phone);
}
