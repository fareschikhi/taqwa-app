import 'package:dio/dio.dart';
import 'package:taqwa/features/data/datasources/halaqa_announcement_remote_datasource.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';

class HalaqaAnnouncementRepository {
  final _ds = HalaqaAnnouncementRemoteDatasource();

  Future<List<HalaqaAnnouncementModel>> myAnnouncements() => _ds.mine();

  Future<List<HalaqaAnnouncementModel>> forHalaqa(int halaqaId) =>
      _ds.forHalaqa(halaqaId);

  Future<HalaqaAnnouncementModel> create(Map<String, dynamic> data) =>
      _ds.create(data);

  Future<HalaqaAnnouncementModel> update(int id, Map<String, dynamic> data) =>
      _ds.update(id, data);

  Future<void> delete(int id) => _ds.delete(id);

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
