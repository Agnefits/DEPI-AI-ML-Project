import 'package:dio/dio.dart';
import '../errors/exception_mapper.dart';
import '../errors/error_handler.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Map the error using ExceptionMapper
    final appException = ExceptionMapper.toAppException(err);

    // Create a new DioException with the AppException as error, so downstream handlers receive it
    final modifiedError = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: appException,
      message: appException.message,
    );

    // Call global ErrorHandler to log it
    ErrorHandler.handleError(appException, err.stackTrace, hint: 'Dio Client');

    // Forward the modified error
    handler.next(modifiedError);
  }
}
