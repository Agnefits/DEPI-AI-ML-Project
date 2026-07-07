import 'dart:async' as async;
import 'dart:io';
import 'package:dio/dio.dart';
import 'app_exception.dart';
import 'network_exception.dart' as net_exc;
import 'failure.dart';

class ExceptionMapper {
  /// Maps any raw exception or error to a concrete [AppException]
  static AppException toAppException(Object error) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      // If the DioException already holds an AppException, return it
      if (error.error is AppException) {
        return error.error as AppException;
      }
      
      // Otherwise map it based on type
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const net_exc.TimeoutException();
        case DioExceptionType.connectionError:
          return const net_exc.NoInternetException();
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final responseData = error.response?.data;
          String message = 'Server error occurred.';
          if (responseData is Map && responseData['message'] != null) {
            message = responseData['message'].toString();
          } else if (responseData is Map && responseData['error'] != null) {
            message = responseData['error'].toString();
          }

          if (statusCode == 400) {
            return ValidationException(message: message, code: 'BAD_REQUEST');
          } else if (statusCode == 401 || statusCode == 403) {
            return AuthException(message: message, code: 'UNAUTHORIZED');
          } else if (statusCode == 404) {
            return ValidationException(message: message, code: 'NOT_FOUND');
          } else if (statusCode == 409) {
            return ValidationException(message: message, code: 'CONFLICT');
          } else if (statusCode == 422) {
            return ValidationException(message: message, code: 'VALIDATION_ERROR');
          } else if (statusCode == 429) {
            return NetworkException(message: 'Too many requests. Please slow down.', code: 'TOO_MANY_REQUESTS');
          } else if (statusCode != null && statusCode >= 500) {
            return const ServerException(message: 'Something went wrong. Please try again.', code: 'SERVER_ERROR');
          }
          return ServerException(message: message, code: 'HTTP_$statusCode');
        default:
          return UnknownException(message: error.message ?? 'An unknown network error occurred.', code: 'DIO_UNKNOWN');
      }
    }

    if (error is SocketException) {
      return const net_exc.NoInternetException();
    }

    if (error is async.TimeoutException) {
      return const net_exc.TimeoutException();
    }

    if (error is FormatException) {
      return const ValidationException(message: 'Invalid data format. Please try again.', code: 'FORMAT_EXCEPTION');
    }

    if (error is TypeError) {
      return const UnknownException(message: 'System error: Type mismatch occurred.', code: 'TYPE_ERROR');
    }

    // Checking for FirebaseExceptions dynamically if they are added later
    final typeString = error.runtimeType.toString();
    if (typeString.contains('FirebaseException') || typeString.contains('FirebaseAuthException')) {
      final msg = error.toString();
      return FirebaseExceptionPlaceholder(
        message: msg.contains('] ') ? msg.split('] ').last : msg,
        code: 'FIREBASE_ERROR',
      );
    }

    return UnknownException(message: error.toString(), code: 'UNKNOWN');
  }

  /// Maps any raw exception or [AppException] to a user-friendly [Failure]
  static Failure toFailure(Object error) {
    final appException = toAppException(error);
    
    if (appException is net_exc.NoInternetException) {
      return NetworkFailure(message: appException.message, code: appException.code);
    } else if (appException is net_exc.TimeoutException) {
      return NetworkFailure(message: appException.message, code: appException.code);
    } else if (appException is NetworkException) {
      return NetworkFailure(message: appException.message, code: appException.code);
    } else if (appException is ServerException) {
      return ServerFailure(message: appException.message, code: appException.code);
    } else if (appException is AuthException) {
      return AuthFailure(message: appException.message, code: appException.code);
    } else if (appException is ValidationException) {
      return ValidationFailure(message: appException.message, code: appException.code);
    } else {
      // Shield the user from technical descriptions for unknown/unhandled exceptions
      return const UnknownFailure(
        message: 'Something went wrong. Please try again.',
        code: 'UNKNOWN',
      );
    }
  }
}
