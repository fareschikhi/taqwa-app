import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/manager_model.dart';

class ManagerRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<ManagerModel>> getAll() async {
    final res = await _dio.get(ApiEndpoints.managers);
    return (res.data as List).map((e) => ManagerModel.fromJson(e)).toList();
  }

  Future<ManagerModel> getOne(int id) async {
    final res = await _dio.get('${ApiEndpoints.managers}/$id');
    return ManagerModel.fromJson(res.data);
  }

  Future<ManagerModel> create(Map<String, dynamic> data) async {
    final res = await _dio.post(ApiEndpoints.managers, data: data);
    return ManagerModel.fromJson(res.data['manager'] ?? res.data);
  }

  Future<ManagerModel> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('${ApiEndpoints.managers}/$id', data: data);
    return ManagerModel.fromJson(res.data);
  }

  Future<ManagerModel> updateStatus(int id, bool isActive) async {
    final res = await _dio.patch(
      '${ApiEndpoints.managers}/$id/status',
      data: {'isActive': isActive},
    );
    return ManagerModel.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('${ApiEndpoints.managers}/$id');
  }

  Future<List<Map<String, dynamic>>> getStudents(int managerId) async {
    final res = await _dio.get('${ApiEndpoints.managers}/$managerId/students');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getHalaqas(int managerId) async {
    final res = await _dio.get('${ApiEndpoints.managers}/$managerId/halaqas');
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
