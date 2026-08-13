import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';

class HalaqaRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<HalaqaModel>> getAll() async {
    final res = await _dio.get('/halaqas');
    return (res.data as List).map((e) => HalaqaModel.fromJson(e)).toList();
  }

  Future<List<HalaqaModel>> getForManager(int managerId) async {
    final res = await _dio.get('/managers/$managerId/halaqas');
    return (res.data as List).map((e) => HalaqaModel.fromJson(e)).toList();
  }

  Future<HalaqaModel> getOne(int id) async {
    final res = await _dio.get('/halaqas/$id');
    return HalaqaModel.fromJson(res.data);
  }

  Future<HalaqaModel> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/halaqas', data: data);
    return HalaqaModel.fromJson(res.data);
  }

  Future<HalaqaModel> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/halaqas/$id', data: data);
    return HalaqaModel.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/halaqas/$id');
  }
}
