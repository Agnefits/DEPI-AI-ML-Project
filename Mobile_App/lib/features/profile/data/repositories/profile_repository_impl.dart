import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> getUserProfile() async {
    return await remoteDataSource.getUserProfile();
  }

  @override
  Future<UserEntity> updateUserProfile(UserEntity user) async {
    return await remoteDataSource.updateProfile(user);
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await remoteDataSource.changePassword(currentPassword, newPassword);
  }

  @override
  Future<void> uploadAvatar(String filePath) async {
    await remoteDataSource.uploadAvatar(filePath);
  }
}
