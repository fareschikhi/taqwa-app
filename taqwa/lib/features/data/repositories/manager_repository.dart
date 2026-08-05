import 'package:dio/dio.dart';
import '../datasources/manager_remote_datasource.dart';
import '../models/manager_model.dart';

class ManagerRepository {
  final _ds = ManagerRemoteDatasource();

  Future<List<ManagerModel>> getAllManagers() => _ds.getAll();

  Future<ManagerModel> getManager(int id) => _ds.getOne(id);

  Future<ManagerModel> createManager(Map<String, dynamic> data) =>
      _ds.create(data);

  Future<ManagerModel> updateManager(int id, Map<String, dynamic> data) =>
      _ds.update(id, data);

  Future<ManagerModel> updateManagerStatus(int id, bool isActive) =>
      _ds.updateStatus(id, isActive);

  Future<void> deleteManager(int id) => _ds.delete(id);

  Future<List<Map<String, dynamic>>> getManagerStudents(int managerId) =>
      _ds.getStudents(managerId);

  Future<List<Map<String, dynamic>>> getManagerHalaqas(int managerId) =>
      _ds.getHalaqas(managerId);

  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }
}
