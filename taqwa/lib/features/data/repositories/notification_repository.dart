import 'package:dio/dio.dart';
import '../datasources/notification_remote_datasource.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final _ds = NotificationRemoteDatasource();

  Future<List<NotificationModel>> getMine() => _ds.getMine();
  Future<int> unreadCount() => _ds.unreadCount();
  Future<void> markRead(int id) => _ds.markRead(id);

  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }
}
