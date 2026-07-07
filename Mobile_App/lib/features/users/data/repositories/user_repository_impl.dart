import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_data_source.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<UserEntity>> getUsers() async {
    return await remoteDataSource.getUsers();
  }

  @override
  Future<UserEntity> getUserById(String id) async {
    final users = await remoteDataSource.getUsers();
    return users.firstWhere((u) => u.id == id);
  }

  @override
  Future<void> addUser(UserEntity user) async {
    await remoteDataSource.addUser(UserModel.fromEntity(user));
  }

  @override
  Future<void> updateUser(UserEntity user) async {
    await remoteDataSource.updateUser(UserModel.fromEntity(user));
  }

  @override
  Future<void> deleteUser(String id) async {
    await remoteDataSource.deleteUser(id);
  }
}
