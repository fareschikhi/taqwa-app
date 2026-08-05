import 'package:dio/dio.dart';
import '../datasources/parent_remote_datasource.dart';
import '../models/parent/parent_model.dart';
import '../models/parent/parent_child_model.dart';
import '../models/parent/parent_payload_dto.dart';

class ParentRepository {
  final _ds = ParentRemoteDatasource();

  Future<List<ParentModel>> getAllParents() => _ds.getAll();

  Future<ParentModel> getParent(int id) => _ds.getOne(id);

  Future<List<ParentChildModel>> getChildren(int parentId) =>
      _ds.getChildren(parentId);

  Future<ParentModel> createParent(ParentPayloadDto parent) =>
      _ds.create(parent);

  Future<ParentModel> updateParent(int id, Map<String, dynamic> data) =>
      _ds.update(id, data);

  Future<void> deleteParent(int id) => _ds.delete(id);

  /// Wraps DioException into a readable message
  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is List && msg.isNotEmpty) return msg.join('\n');
        if (msg is String && msg.isNotEmpty) return msg;
        if (data['error'] is String) return data['error'];
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
      return e.message ?? 'حدث خطأ في الاتصال بالخادم';
    }
    return e.toString();
  }
}
