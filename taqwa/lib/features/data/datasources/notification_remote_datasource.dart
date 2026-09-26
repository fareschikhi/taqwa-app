import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import '../models/notification_model.dart';

class NotificationRemoteDatasource {
  final Dio _dio = DioClient.instance;

  /// Narrows a request to one child's notifications, plus those about no
  /// child in particular. Null asks for all of them.
  Map<String, dynamic>? _scope(int? studentId) =>
      studentId == null ? null : {'studentId': studentId};

  Future<List<NotificationModel>> getMine({int? studentId}) async {
    final response = await _dio.get(
      '${ApiEndpoints.notifications}/me',
      queryParameters: _scope(studentId),
    );
    return (response.data as List)
        .whereType<Map>()
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> unreadCount({int? studentId}) async {
    final response = await _dio.get(
      '${ApiEndpoints.notifications}/me/unread',
      queryParameters: _scope(studentId),
    );
    return ((response.data as Map)['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int id) async {
    await _dio.patch('${ApiEndpoints.notifications}/$id/read');
  }

  Future<void> markAllRead({int? studentId}) async {
    await _dio.post(
      '${ApiEndpoints.notifications}/me/read-all',
      queryParameters: _scope(studentId),
    );
  }
}
