import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/add_user_usecase.dart';
import '../../domain/usecases/update_user_usecase.dart';
import 'users_event.dart';
import 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final GetUsersUseCase getUsersUseCase;
  final AddUserUseCase addUserUseCase;
  final UpdateUserUseCase updateUserUseCase;

  UsersBloc({
    required this.getUsersUseCase,
    required this.addUserUseCase,
    required this.updateUserUseCase,
  }) : super(UsersInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<AddUser>(_onAddUser);
    on<UpdateUser>(_onUpdateUser);
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<UsersState> emit) async {
    emit(UsersLoading());
    try {
      final users = await getUsersUseCase();
      emit(UsersLoaded(users));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<void> _onAddUser(AddUser event, Emitter<UsersState> emit) async {
    emit(UsersLoading());
    try {
      await addUserUseCase(event.user);
      emit(const UserOperationSuccess('User added successfully'));
      add(LoadUsers());
    } catch (e) {
      emit(UsersError(e.toString()));
      add(LoadUsers());
    }
  }

  Future<void> _onUpdateUser(UpdateUser event, Emitter<UsersState> emit) async {
    emit(UsersLoading());
    try {
      await updateUserUseCase(event.user);
      emit(const UserOperationSuccess('User updated successfully'));
      add(LoadUsers());
    } catch (e) {
      emit(UsersError(e.toString()));
      add(LoadUsers());
    }
  }
}
