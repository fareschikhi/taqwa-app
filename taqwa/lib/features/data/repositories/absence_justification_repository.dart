import 'package:dio/dio.dart';
import '../datasources/absence_justification_remote_datasource.dart';
import '../models/absence_justification_model.dart';
import '../models/unjustified_attendance_model.dart';

class AbsenceJustificationRepository {
  final _ds = AbsenceJustificationRemoteDatasource();

  Future<List<AbsenceJustificationModel>> getAllJustifications({
    int? managerId,
    int? studentId,
  }) =>
      _ds.getAll(managerId: managerId, studentId: studentId);

  Future<List<UnjustifiedAttendanceModel>> getUnjustified(int managerId) =>
      _ds.getUnjustified(managerId);

  Future<AbsenceJustificationModel> getJustification(int id) =>
      _ds.getOne(id);

  Future<AbsenceJustificationModel> createJustification(
          Map<String, dynamic> data) =>
      _ds.create(data);

  Future<AbsenceJustificationModel> updateJustification(
          int id, Map<String, dynamic> data) =>
      _ds.update(id, data);

  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }
}
