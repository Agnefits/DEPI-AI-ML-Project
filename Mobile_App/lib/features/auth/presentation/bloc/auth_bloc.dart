import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../domain/entities/auth_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/models/auth_model.dart';
import '../../../../core/errors/failure.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final ForgotPasswordUseCase forgotPasswordUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final ResetPasswordUseCase resetPasswordUseCase;
  final AuthLocalDataSource localDataSource;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.forgotPasswordUseCase,
    required this.verifyOtpUseCase,
    required this.resetPasswordUseCase,
    required this.localDataSource,
  }) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<ForgotPasswordRequested>(_onForgotPasswordRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
  }

  Future<void> _onCheckAuthStatus(
      CheckAuthStatus event, Emitter<AuthState> emit) async {
    final auth = await localDataSource.loadAuth();
    if (auth != null) {
      emit(AuthAuthenticated(auth));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final Result<AuthEntity, Failure> result = await loginUseCase(event.email, event.password);
    
    await result.fold(
      (user) async {
        await localDataSource.saveAuth(
          AuthModel(
            id: user.id,
            email: user.email,
            name: user.name,
            token: user.token,
            refreshToken: user.refreshToken,
          ),
        );
        emit(AuthAuthenticated(user));
      },
      (failure) async {
        emit(AuthError(failure.message));
      },
    );
  }

  Future<void> _onRegisterRequested(
      RegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final Result<AuthEntity, Failure> result = await registerUseCase(
      event.username,
      event.fullName,
      event.email,
      event.password,
      phone: event.phone,
    );

    if (result is Success<AuthEntity, Failure>) {
      final user = result.value;
      if (user.token.isNotEmpty) {
        await localDataSource.saveAuth(
          AuthModel(
            id: user.id,
            email: user.email,
            name: user.name,
            token: user.token,
            refreshToken: user.refreshToken,
          ),
        );
        emit(AuthAuthenticated(user));
        return;
      }

      // Register succeeded but no token returned — auto-login
      final Result<AuthEntity, Failure> loginResult = await loginUseCase(
        event.username,
        event.password,
      );

      await loginResult.fold(
        (user) async {
          await localDataSource.saveAuth(
            AuthModel(
              id: user.id,
              email: user.email,
              name: user.name,
              token: user.token,
              refreshToken: user.refreshToken,
            ),
          );
          emit(AuthAuthenticated(user));
        },
        (failure) async {
          emit(AuthError(failure.message));
        },
      );
      return;
    }

    // Register failed
    final failure = (result as FailureResult<AuthEntity, Failure>).failure;
    emit(AuthError(failure.message));
  }

  Future<void> _onForgotPasswordRequested(
      ForgotPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final Result<void, Failure> result = await forgotPasswordUseCase(event.email);
    
    result.fold(
      (_) {
        emit(AuthPasswordResetSuccess());
      },
      (failure) {
        emit(AuthError(failure.message));
      },
    );
  }

  Future<void> _onVerifyOtpRequested(
      VerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final Result<void, Failure> result = await verifyOtpUseCase(event.email, event.otpCode);

    result.fold(
      (_) {
        emit(AuthOtpVerified());
      },
      (failure) {
        emit(AuthError(failure.message));
      },
    );
  }

  Future<void> _onResetPasswordRequested(
      ResetPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final Result<void, Failure> result = await resetPasswordUseCase(event.email, event.otpCode, event.newPassword);

    result.fold(
      (_) {
        emit(AuthPasswordResetSuccess());
      },
      (failure) {
        emit(AuthError(failure.message));
      },
    );
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    await localDataSource.clearAuth();
    emit(AuthUnauthenticated());
  }
}
