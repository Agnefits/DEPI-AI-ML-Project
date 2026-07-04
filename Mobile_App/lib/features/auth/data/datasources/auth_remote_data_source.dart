import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/login_request_model.dart';
import '../models/register_request_model.dart';
import '../../../../core/network/dio_client.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(LoginRequestModel request);
  Future<UserModel> register(RegisterRequestModel request);
  Future<void> forgotPassword(String email);
  Future<void> verifyOtp(String email, String otpCode);
  Future<void> resetPassword(String email, String otpCode, String newPassword);
  Future<UserModel> refreshToken(String accessToken, String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient client;

  AuthRemoteDataSourceImpl({required this.client});

  @override
  Future<UserModel> login(LoginRequestModel request) async {
    try {
      final response = await client.dio.post(
        '/Auth/login',
        data: request.toJson(),
      );

      final data = response.data is Map ? response.data as Map<String, dynamic> : {};
      final token = (data['token'] ?? data['accessToken'] ?? '') as String;
      final claims = _decodeJwt(token);

      return UserModel(
        id: claims['id'] ?? data['id']?.toString() ?? '',
        email: claims['email'] ?? request.username,
        name: claims['name'] ?? data['name']?.toString() ?? '',
        token: token,
        refreshToken: (data['refreshToken'] ?? '') as String,
      );
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      throw Exception(message);
    }
  }

  @override
  Future<UserModel> register(RegisterRequestModel request) async {
    try {
      final response = await client.dio.post(
        '/Auth/register',
        data: request.toJson(),
      );

      final data = response.data is Map ? response.data as Map<String, dynamic> : {};
      final token = (data['token'] ?? data['accessToken'] ?? '') as String;
      final claims = _decodeJwt(token);

      return UserModel(
        id: claims['id'] ?? data['id']?.toString() ?? '',
        email: claims['email'] ?? request.email,
        name: claims['name'] ?? request.fullName,
        token: token,
        refreshToken: (data['refreshToken'] ?? '') as String,
      );
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      throw Exception(message);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await client.dio.post('/Auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> verifyOtp(String email, String otpCode) async {
    try {
      await client.dio.post(
        '/Auth/verify-otp',
        data: {'email': email, 'otpCode': otpCode},
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> resetPassword(String email, String otpCode, String newPassword) async {
    try {
      await client.dio.post(
        '/Auth/reset-password',
        data: {'email': email, 'otpCode': otpCode, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data['message'] != null) return data['message'].toString();
      if (data['title'] != null) return data['title'].toString();
    }
    if (e.response?.data is String) {
      return e.response!.data as String;
    }
    return e.message ?? 'Failed to connect to the server';
  }

  @override
  Future<UserModel> refreshToken(String accessToken, String refreshToken) async {
    try {
      final response = await client.dio.post(
        '/Auth/refresh',
        data: {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        },
      );

      final data = response.data is Map ? response.data as Map<String, dynamic> : {};
      final newToken = (data['accessToken'] ?? data['token'] ?? '') as String;
      final newRefreshToken = (data['refreshToken'] ?? '') as String;
      final claims = _decodeJwt(newToken);

      return UserModel(
        id: claims['id'] ?? '',
        email: claims['email'] ?? '',
        name: claims['name'] ?? '',
        token: newToken,
        refreshToken: newRefreshToken,
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Map<String, String> _decodeJwt(String token) {
    if (token.isEmpty) return {};
    try {
      final parts = token.split('.');
      if (parts.length < 2) return {};
      final payload = parts[1];
      final normalized = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      return {
        'id': json[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
            ?.toString() ?? '',
        'name': json[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name']
            ?.toString() ?? '',
        'email': json[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']
            ?.toString() ?? '',
      };
    } catch (_) {
      return {};
    }
  }
}
