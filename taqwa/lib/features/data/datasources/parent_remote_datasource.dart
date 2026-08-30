import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import '../models/parent/parent_model.dart';
import '../models/parent/parent_child_model.dart';
import '../models/parent/parent_payload_dto.dart';

class ParentRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<ParentModel>> getAll() async {
    final res = await _dio.get(ApiEndpoints.parents);
    return (res.data as List).map((e) => ParentModel.fromJson(e)).toList();
  }

  Future<ParentModel> getOne(int id) async {
    final res = await _dio.get('${ApiEndpoints.parents}/$id');
    return ParentModel.fromJson(res.data);
  }

  Future<List<ParentChildModel>> getChildren(int parentId) async {
    final res = await _dio.get('${ApiEndpoints.parents}/$parentId/children');
    return (res.data as List)
        .map((e) => ParentChildModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// An adult student has no parent record, so there is no `/children` list
  /// to fetch. GET /students/:id returns the same `user`/`halaqa`/`_count`
  /// shape that GET /parents/:id/children returns per child, so it parses
  /// with the same model; the ownership guard on that route is what keeps
  /// him from reaching anyone else's record.
  Future<ParentChildModel> getSelf(int studentId) async {
    final res = await _dio.get('${ApiEndpoints.students}/$studentId');
    return ParentChildModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ParentModel> create(ParentPayloadDto dto) async {
    final res = await _dio.post(ApiEndpoints.parents, data: dto.toJson());
    return ParentModel.fromJson(res.data);
  }

  Future<ParentModel> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('${ApiEndpoints.parents}/$id', data: data);
    return ParentModel.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('${ApiEndpoints.parents}/$id');
  }
}
