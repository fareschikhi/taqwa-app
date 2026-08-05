import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('--> ${options.method} ${options.uri}');
      print('Headers: ${options.headers}');
      print('Body: ${options.data}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('<-- ${response.statusCode} ${response.requestOptions.uri}');
      print('Response: ${response.data}');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('xxx Error: ${err.message}');
      print('xxx Response: ${err.response?.data}');
    }
    super.onError(err, handler);
  }
}
