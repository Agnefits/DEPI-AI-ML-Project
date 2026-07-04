import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object> get props => [];
}

class LoadProfileEvent extends ProfileEvent {}

class UpdateProfileEvent extends ProfileEvent {
  final UserEntity user;

  const UpdateProfileEvent(this.user);

  @override
  List<Object> get props => [user];
}

class UploadAvatarEvent extends ProfileEvent {
  final String filePath;

  const UploadAvatarEvent(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class ChangePasswordEvent extends ProfileEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordEvent({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object> get props => [currentPassword, newPassword];
}
