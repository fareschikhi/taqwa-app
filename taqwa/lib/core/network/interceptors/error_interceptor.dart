import 'package:dio/dio.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String message = 'حدث خطأ غير متوقع';
    if (err.type == DioExceptionType.connectionTimeout || 
        err.type == DioExceptionType.receiveTimeout || 
        err.type == DioExceptionType.sendTimeout) {
      message = 'فشل الاتصال بالخادم، يرجى التحقق من الشبكة';
    } else if (err.response != null) {
      final data = err.response!.data;
      if (data is Map && data['message'] != null) {
        if (data['message'] is List) {
          message = (data['message'] as List).join('\n');
        } else {
          message = data['message'].toString();
        }
      } else if (err.response!.statusCode == 401) {
        message = 'جلسة العمل انتهت أو غير مصرح لك بالدخول';
      }
    }
    
    super.onError(err.copyWith(error: message), handler);
  }
}
