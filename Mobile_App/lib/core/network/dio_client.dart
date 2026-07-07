import 'package:dio/dio.dart';
import 'api_constants.dart';
import 'error_interceptor.dart';
import '../constants/app_constants.dart';

class DioClient {
  late final Dio dio;

  DioClient({Future<String?> Function()? tokenProvider}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (tokenProvider != null) {
      dio.interceptors.add(_AuthInterceptor(tokenProvider));
    }

    dio.interceptors.add(ErrorInterceptor());

    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));
  }
}

class _AuthInterceptor extends Interceptor {
  final Future<String?> Function() tokenProvider;

  _AuthInterceptor(this.tokenProvider);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await tokenProvider();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid - could emit logout event
    }
    handler.next(err);
  }
}
