import 'package:dio/dio.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String message = 'حدث خطأ غير متوقع';
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      // A timeout means the socket opened and the server simply answered too
      // slowly, so the user's connection is working. Sending them off to check
      // their network makes them debug something that is not broken.
      message = 'الخادم لا يستجيب، يرجى المحاولة مرة أخرى';
    } else if (err.type == DioExceptionType.connectionError) {
      // Nothing answered at the other end: no DNS, no route, refused socket.
      // This is the case where the network really is worth checking.
      message = 'تعذّر الاتصال بالخادم، يرجى التحقق من الشبكة';
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
