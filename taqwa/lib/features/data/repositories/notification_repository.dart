import 'package:dio/dio.dart';
import '../datasources/notification_remote_datasource.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final _ds = NotificationRemoteDatasource();

  Future<List<NotificationModel>> getMine({int? studentId}) =>
      _ds.getMine(studentId: studentId);
  Future<int> unreadCount({int? studentId}) =>
      _ds.unreadCount(studentId: studentId);
  Future<void> markRead(int id) => _ds.markRead(id);
  Future<void> markAllRead({int? studentId}) =>
      _ds.markAllRead(studentId: studentId);

  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }
}
