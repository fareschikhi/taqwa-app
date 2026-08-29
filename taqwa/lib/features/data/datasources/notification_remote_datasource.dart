import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import '../models/notification_model.dart';

class NotificationRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<NotificationModel>> getMine() async {
    final response = await _dio.get('${ApiEndpoints.notifications}/me');
    return (response.data as List)
        .whereType<Map>()
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> unreadCount() async {
    final response = await _dio.get('${ApiEndpoints.notifications}/me/unread');
    return ((response.data as Map)['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int id) async {
    await _dio.patch('${ApiEndpoints.notifications}/$id/read');
  }
}
