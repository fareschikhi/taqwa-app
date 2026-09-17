import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';

class HalaqaAnnouncementRemoteDatasource {
  final Dio _dio = DioClient.instance;

  static const _base = ApiEndpoints.halaqaAnnouncements;

  /// The caller's own feed. The server decides which halaqas that covers, so
  /// every role calls this same route.
  Future<List<HalaqaAnnouncementModel>> mine() async {
    final res = await _dio.get('$_base/mine');
    return _list(res.data);
  }

  Future<List<HalaqaAnnouncementModel>> forHalaqa(int halaqaId) async {
    final res = await _dio.get('$_base/halaqa/$halaqaId');
    return _list(res.data);
  }

  Future<HalaqaAnnouncementModel> create(Map<String, dynamic> data) async {
    final res = await _dio.post(_base, data: data);
    return HalaqaAnnouncementModel.fromJson(res.data);
  }

  Future<HalaqaAnnouncementModel> update(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _dio.patch('$_base/$id', data: data);
    return HalaqaAnnouncementModel.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('$_base/$id');
  }

  List<HalaqaAnnouncementModel> _list(dynamic data) =>
      (data as List).map((e) => HalaqaAnnouncementModel.fromJson(e)).toList();
}
