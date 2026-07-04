import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

class LoadUsers extends UsersEvent {}

class AddUser extends UsersEvent {
  final UserEntity user;
  const AddUser(this.user);
  @override
  List<Object?> get props => [user];
}

class UpdateUser extends UsersEvent {
  final UserEntity user;
  const UpdateUser(this.user);
  @override
  List<Object?> get props => [user];
}

class DeleteUser extends UsersEvent {
  final String id;
  const DeleteUser(this.id);
  @override
  List<Object?> get props => [id];
}
