import '../entities/user_entity.dart';

abstract class ProfileRepository {
  Future<UserEntity> getUserProfile();
  Future<UserEntity> updateUserProfile(UserEntity user);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> uploadAvatar(String filePath);
}
