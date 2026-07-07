import '../../../../core/errors/failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_entity.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_model.dart';
import '../models/login_request_model.dart';
import '../models/register_request_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<AuthEntity, Failure>> login(String email, String password) async {
    try {
      final request = LoginRequestModel(username: email, password: password);
      final userModel = await remoteDataSource.login(request);
      final entity = AuthModel(
        id: userModel.id,
        email: userModel.email,
        name: userModel.name,
        token: userModel.token,
        refreshToken: userModel.refreshToken,
      );
      return Success(entity);
    } catch (e, s) {
      final failure = ErrorHandler.handleRepositoryError(e, s);
      return FailureResult(failure);
    }
  }

  @override
  Future<Result<AuthEntity, Failure>> register(String username, String fullName, String email, String password, {String phone = ''}) async {
    try {
      final request = RegisterRequestModel(
        username: username,
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
      );
      final userModel = await remoteDataSource.register(request);
      final entity = AuthModel(
        id: userModel.id,
        email: userModel.email,
        name: userModel.name,
        token: userModel.token,
        refreshToken: userModel.refreshToken,
      );
      return Success(entity);
    } catch (e, s) {
      final failure = ErrorHandler.handleRepositoryError(e, s);
      return FailureResult(failure);
    }
  }

  @override
  Future<Result<void, Failure>> forgotPassword(String email) async {
    try {
      await remoteDataSource.forgotPassword(email);
      return const Success(null);
    } catch (e, s) {
      final failure = ErrorHandler.handleRepositoryError(e, s);
      return FailureResult(failure);
    }
  }

  @override
  Future<Result<void, Failure>> verifyOtp(String email, String otp) async {
    try {
      await remoteDataSource.verifyOtp(email, otp);
      return const Success(null);
    } catch (e, s) {
      final failure = ErrorHandler.handleRepositoryError(e, s);
      return FailureResult(failure);
    }
  }

  @override
  Future<Result<void, Failure>> resetPassword(String email, String otpCode, String newPassword) async {
    try {
      await remoteDataSource.resetPassword(email, otpCode, newPassword);
      return const Success(null);
    } catch (e, s) {
      final failure = ErrorHandler.handleRepositoryError(e, s);
      return FailureResult(failure);
    }
  }
}
