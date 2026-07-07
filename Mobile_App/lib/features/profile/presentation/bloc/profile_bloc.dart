import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/get_user_profile_usecase.dart';
import '../../domain/usecases/update_user_profile_usecase.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserProfileUseCase getUserProfile;
  final UpdateUserProfileUseCase updateUserProfile;
  final ChangePasswordUseCase changePassword;
  final UploadAvatarUseCase uploadAvatarUseCase;

  ProfileBloc({
    required this.getUserProfile,
    required this.updateUserProfile,
    required this.changePassword,
    required this.uploadAvatarUseCase,
  }) : super(ProfileInitial()) {
    on<LoadProfileEvent>((event, emit) async {
      emit(ProfileLoading());
      try {
        final user = await getUserProfile();
        emit(ProfileLoaded(user));
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });

    on<UpdateProfileEvent>((event, emit) async {
      emit(ProfileLoading());
      try {
        final user = await updateUserProfile(event.user);
        emit(ProfileUpdateSuccess(user));
        emit(ProfileLoaded(user));
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });

    on<UploadAvatarEvent>((event, emit) async {
      emit(ProfileLoading());
      try {
        await uploadAvatarUseCase(event.filePath);
        emit(ProfileAvatarUploadSuccess());
        final user = await getUserProfile();
        emit(ProfileLoaded(user));
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });

    on<ChangePasswordEvent>((event, emit) async {
      emit(ProfileLoading());
      try {
        await changePassword(event.currentPassword, event.newPassword);
        emit(ProfilePasswordChangeSuccess());
        final user = await getUserProfile();
        emit(ProfileLoaded(user));
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });
  }
}
