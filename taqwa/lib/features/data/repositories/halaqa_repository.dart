import 'package:dio/dio.dart';
import 'package:taqwa/features/data/datasources/halaqa_remote_datasource.dart';
import 'package:taqwa/core/models/halaqa_model.dart';

class HalaqaRepository {
  final _ds = HalaqaRemoteDatasource();

  Future<List<HalaqaModel>> getAllHalaqas() => _ds.getAll();

  Future<HalaqaModel> getHalaqa(int id) => _ds.getOne(id);

  Future<HalaqaModel> createHalaqa(Map<String, dynamic> data) =>
      _ds.create(data);

  Future<HalaqaModel> updateHalaqa(int id, Map<String, dynamic> data) =>
      _ds.update(id, data);

  Future<void> deleteHalaqa(int id) => _ds.delete(id);

  /// Wraps DioException into a readable Arabic message
  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }
}
