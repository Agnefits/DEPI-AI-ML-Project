import '../entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class GetUserProfileUseCase {
  final ProfileRepository repository;

  GetUserProfileUseCase(this.repository);

  Future<UserEntity> call() async {
    return await repository.getUserProfile();
  }
}
