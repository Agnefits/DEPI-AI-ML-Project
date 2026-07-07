import '../entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateUserProfileUseCase {
  final ProfileRepository repository;

  UpdateUserProfileUseCase(this.repository);

  Future<UserEntity> call(UserEntity user) async {
    return await repository.updateUserProfile(user);
  }
}
