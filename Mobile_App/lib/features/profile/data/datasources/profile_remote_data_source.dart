import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../../../core/network/dio_client.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getUserProfile();
  Future<UserModel> updateProfile(UserEntity user);
  Future<void> uploadAvatar(String filePath);
  Future<void> changePassword(String oldPassword, String newPassword);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final DioClient client;

  ProfileRemoteDataSourceImpl({
    required this.client,
  });

  @override
  Future<UserModel> getUserProfile() async {
    final response = await client.dio.get('/Profile');

    final data = response.data is Map
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};

    return UserModel.fromJson(data);
  }

  @override
  Future<UserModel> updateProfile(UserEntity user) async {
    final response = await client.dio.put(
      '/Profile',
      data: {
        'fullName': user.name,
        'phone': user.phoneNumber,
        'specialization': user.specialization,
      },
    );

    final data = response.data is Map
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};

    return UserModel.fromJson(data);
  }

  @override
  Future<void> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    await client.dio.post(
      '/Profile/upload-avatar',
      data: formData,
    );
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await client.dio.post(
      '/Profile/change-password',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }
}
