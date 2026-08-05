import 'package:dio/dio.dart';
import 'package:taqwa/core/models/teacher/teacher_payload_dto.dart';
import 'package:taqwa/core/models/teacher/teacher_model.dart';
import '../../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/attendance_summary_model.dart';
import '../models/revision_needed_model.dart';
import '../models/memorization_progress_summary_model.dart';
import '../models/teacher_student_model.dart';
import '../models/student_note_model.dart';

class TeacherRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<TeacherModel>> getAll() async {
    final res = await _dio.get(ApiEndpoints.teachers);
    return (res.data as List).map((e) => TeacherModel.fromJson(e)).toList();
  }

  Future<TeacherModel> getOne(int id) async {
    final res = await _dio.get('${ApiEndpoints.teachers}/$id');
    return TeacherModel.fromJson(res.data);
  }

  Future<TeacherModel> create(TeacherPayloadDto dto) async {
    final res = await _dio.post(ApiEndpoints.teachers, data: dto.toJson());
    return TeacherModel.fromJson(res.data);
  }

  Future<TeacherModel> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('${ApiEndpoints.teachers}/$id', data: data);
    return TeacherModel.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/teachers/$id');
  }

  // ─── Teacher functionalities ──────────────────────────────────────────────────────────────
  Future<AttendanceSummaryModel> getAttendanceSummary(int teacherId) async {
    final response = await _dio.get(
      '${ApiEndpoints.teachers}/$teacherId/attendance-summary',
    );
    return AttendanceSummaryModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<List<RevisionNeededModel>> getRevisionNeeded(int teacherId) async {
    final response = await _dio.get(
      '${ApiEndpoints.teachers}/$teacherId/revision-needed',
    );
    return (response.data as List)
        .map((e) => RevisionNeededModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MemorizationProgressSummaryModel> getMemorizationProgress(
    int teacherId,
  ) async {
    final response = await _dio.get(
      '${ApiEndpoints.teachers}/$teacherId/memorization-progress',
    );
    return MemorizationProgressSummaryModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  // ─── Students ──────────────────────────────────────────────────────────────

  Future<StudentListResponse> getStudents({
    required int teacherId,
    String? search,
    int page = 1,
    int limit = 30,
    bool? isActive,
  }) async {
    final queryParams = <String, dynamic>{
      'teacherId': teacherId,
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (isActive != null) 'isActive': isActive.toString(),
    };
    final response = await _dio.get(
      ApiEndpoints.students,
      queryParameters: queryParams,
    );
    return StudentListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Attendance ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    final response = await _dio.get(
      '${ApiEndpoints.attendance}/date',
      queryParameters: {'date': date},
    );
    return (response.data as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> submitAttendanceBatch(
    List<Map<String, dynamic>> records,
  ) async {
    final response = await _dio.post(
      '${ApiEndpoints.attendance}/batch',
      data: {'records': records},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMemorizationByDate(String date) async {
    final response = await _dio.get(
      '${ApiEndpoints.memorization}/date',
      queryParameters: {'date': date},
    );
    return (response.data as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> upsertAttendance({
    required int studentId,
    required String date,
    required String status,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.attendance,
      data: {'studentId': studentId, 'date': date, 'status': status},
    );
    return response.data as Map<String, dynamic>;
  }

  // ─── Notes ─────────────────────────────────────────────────────────────────

  Future<List<StudentNoteModel>> getNotesByTeacher(int teacherId) async {
    final response = await _dio.get(
      '${ApiEndpoints.studentNotes}/teacher/$teacherId',
    );
    return (response.data as List)
        .map((e) => StudentNoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StudentNoteModel> createNote({
    required int studentId,
    required int teacherId,
    required String note,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.studentNotes,
      data: {'studentId': studentId, 'teacherId': teacherId, 'note': note},
    );
    return StudentNoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteNote(int id) async {
    await _dio.delete('${ApiEndpoints.studentNotes}/$id');
  }

  // ─── Memorization ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitMemorization({
    required int studentId,
    required int surahNumber,
    required int pagesDone,
    required String memorizationType,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.memorization,
      data: {
        'studentId': studentId,
        'surahNumber': surahNumber,
        'pagesDone': pagesDone,
        'memorizationType': memorizationType,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
