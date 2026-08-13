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
          // The API sits on Render's free plan, which stops the service once it
          // goes idle and only boots it again on the next request. A cold start
          // measured 51-54s against the deployed API; warm requests answer in
          // ~1.3s. The socket connects in ~80ms either way, so the wait is the
          // response, not the network — receiveTimeout is what has to absorb it.
          // At the previous 10s the first login after any quiet period always
          // failed, and the error interceptor blamed the user's network for it.
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 90),
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
