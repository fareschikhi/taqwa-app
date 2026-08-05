import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/absence_justification_model.dart';

class AbsenceJustificationRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<AbsenceJustificationModel>> getAll({
    int? managerId,
    int? studentId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (managerId != null) queryParams['managerId'] = managerId;
    if (studentId != null) queryParams['studentId'] = studentId;

    final res = await _dio.get(
      ApiEndpoints.absenceJustifications,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return (res.data as List)
        .map((e) => AbsenceJustificationModel.fromJson(e))
        .toList();
  }

  Future<AbsenceJustificationModel> getOne(int id) async {
    final res =
        await _dio.get('${ApiEndpoints.absenceJustifications}/$id');
    return AbsenceJustificationModel.fromJson(res.data);
  }

  Future<AbsenceJustificationModel> create(
      Map<String, dynamic> data) async {
    final res =
        await _dio.post(ApiEndpoints.absenceJustifications, data: data);
    return AbsenceJustificationModel.fromJson(res.data);
  }

  Future<AbsenceJustificationModel> update(
      int id, Map<String, dynamic> data) async {
    final res = await _dio.patch(
        '${ApiEndpoints.absenceJustifications}/$id',
        data: data);
    return AbsenceJustificationModel.fromJson(res.data);
  }
}
