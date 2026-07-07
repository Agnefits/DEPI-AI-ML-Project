import '../models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<List<UserModel>> getUsers();
  Future<void> addUser(UserModel user);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(String id);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final List<UserModel> _mockUsers = [
    const UserModel(id: '1', name: 'Dr. John Doe', email: 'john@clinicai.com', role: 'Doctor', phone: '+1234567890', status: 'Active'),
    const UserModel(id: '2', name: 'Jane Smith', email: 'jane@clinicai.com', role: 'Nurse', phone: '+1987654321', status: 'Inactive'),
  ];

  @override
  Future<List<UserModel>> getUsers() async {
    await Future.delayed(const Duration(seconds: 1));
    return _mockUsers;
  }

  @override
  Future<void> addUser(UserModel user) async {
    await Future.delayed(const Duration(seconds: 1));
    _mockUsers.add(user);
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await Future.delayed(const Duration(seconds: 1));
    final index = _mockUsers.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _mockUsers[index] = user;
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    await Future.delayed(const Duration(seconds: 1));
    _mockUsers.removeWhere((u) => u.id == id);
  }
}
