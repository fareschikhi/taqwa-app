import 'package:dio/dio.dart';
import 'api_endpoints.dart';
import 'interceptors/jwt_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/error_interceptor.dart';

class DioClient {
  static Dio? _dio;

  static Dio get instance {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      _dio!.interceptors.addAll([
        JwtInterceptor(),
        LoggingInterceptor(),
        ErrorInterceptor(),
      ]);
    }
    return _dio!;
  }
}
