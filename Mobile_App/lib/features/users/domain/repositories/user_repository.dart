import '../entities/user_entity.dart';

abstract class UserRepository {
  Future<List<UserEntity>> getUsers();
  Future<UserEntity> getUserById(String id);
  Future<void> addUser(UserEntity user);
  Future<void> updateUser(UserEntity user);
  Future<void> deleteUser(String id);
}
