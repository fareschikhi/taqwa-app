import 'package:dio/dio.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import '../models/student/student_model.dart';
import '../models/attendance_summary_model.dart';

class StudentRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<StudentModel>> getAll() async {
    final res = await _dio.get('/students');
    return (res.data['data'] as List)
        .map((e) => StudentModel.fromJson(e))
        .toList();
  }

  /// The backend paginates `/students` and caps `data` at the page's
  /// `limit`, but the response still carries the real `total` count.
  Future<int> getCount() async {
    final res = await _dio.get('/students');
    return res.data['total'] as int;
  }

  Future<StudentModel> getOne(int id) async {
    final res = await _dio.get('/students/$id');
    return StudentModel.fromJson(res.data);
  }

  Future<StudentModel> create(StudentPayloadDto student) async {
    final res = await _dio.post('/students', data: student.toJson());
    return StudentModel.fromJson(res.data);
  }

  Future<StudentModel> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/students/$id', data: data);
    return StudentModel.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/students/$id');
  }

  Future<Map<String, dynamic>> getProfile(int id) async {
    final res = await _dio.get('/students/$id/profile');
    return res.data as Map<String, dynamic>;
  }

  Future<AttendanceSummaryModel> getAttendanceSummary(int studentId) async {
    final res = await _dio.get(
      '${ApiEndpoints.attendance}/student/$studentId/summary',
    );
    return AttendanceSummaryModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory(
    int studentId,
  ) async {
    final res = await _dio.get(
      '${ApiEndpoints.attendance}/student/$studentId',
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Returns the raw { records, totalPagesDone, totalSurahs, typeCounts }
  /// shape from MemorizationService.getStudentProgress — there is no
  /// backend concept of "% of Quran memorized" for a single student.
  Future<Map<String, dynamic>> getMemorizationProgress(int studentId) async {
    final res = await _dio.get(
      '${ApiEndpoints.memorization}/student/$studentId/progress',
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMemorizationHistory(
    int studentId,
  ) async {
    final res = await _dio.get(
      '${ApiEndpoints.memorization}/student/$studentId',
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
