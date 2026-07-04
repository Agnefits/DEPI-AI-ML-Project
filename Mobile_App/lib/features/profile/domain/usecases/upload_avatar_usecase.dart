import '../repositories/profile_repository.dart';

class UploadAvatarUseCase {
  final ProfileRepository repository;

  UploadAvatarUseCase(this.repository);

  Future<void> call(String filePath) {
    return repository.uploadAvatar(filePath);
  }
}
