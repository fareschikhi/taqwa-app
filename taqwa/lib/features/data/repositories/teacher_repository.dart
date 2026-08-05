import 'package:dio/dio.dart';
import 'package:taqwa/core/models/teacher/teacher_payload_dto.dart';
import 'package:taqwa/core/models/teacher/teacher_model.dart';
import '../datasources/teacher_remote_datasource.dart';
import '../models/attendance_summary_model.dart';
import '../models/revision_needed_model.dart';
import '../models/memorization_progress_summary_model.dart';
import '../models/teacher_student_model.dart';
import '../models/student_note_model.dart';

class TeacherRepository {
  final _ds = TeacherRemoteDatasource();

  Future<List<TeacherModel>> getAllTeachers() => _ds.getAll();

  Future<TeacherModel> getTeacher(int id) => _ds.getOne(id);

  Future<TeacherModel> createTeacher(TeacherPayloadDto teacher) =>
      _ds.create(teacher);

  Future<TeacherModel> updateTeacher(int id, Map<String, dynamic> data) =>
      _ds.update(id, data);

  Future<void> deleteTeacher(int id) => _ds.delete(id);

  /// Wraps DioException into a readable Arabic message
  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }

  // ─── Teacher functionalities ──────────────────────────────────────────────────────────────
  Future<AttendanceSummaryModel> getAttendanceSummary(int teacherId) async {
    return _ds.getAttendanceSummary(teacherId);
  }

  Future<List<RevisionNeededModel>> getRevisionNeeded(int teacherId) async {
    return _ds.getRevisionNeeded(teacherId);
  }

  Future<MemorizationProgressSummaryModel> getMemorizationProgress(
    int teacherId,
  ) async {
    return _ds.getMemorizationProgress(teacherId);
  }

  // ─── Students ──────────────────────────────────────────────────────────────

  Future<StudentListResponse> getStudents({
    required int teacherId,
    String? search,
    int page = 1,
    int limit = 30,
    bool? isActive,
  }) async {
    return _ds.getStudents(
      teacherId: teacherId,
      search: search,
      page: page,
      limit: limit,
      isActive: isActive,
    );
  }

  // ─── Attendance ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    return _ds.getAttendanceByDate(date);
  }

  Future<void> submitAttendanceBatch(List<Map<String, dynamic>> records) async {
    await _ds.submitAttendanceBatch(records);
  }

  Future<List<Map<String, dynamic>>> getMemorizationByDate(String date) async {
    return _ds.getMemorizationByDate(date);
  }

  Future<void> upsertAttendance({
    required int studentId,
    required String date,
    required String status,
  }) async {
    await _ds.upsertAttendance(
      studentId: studentId,
      date: date,
      status: status,
    );
  }

  // ─── Notes ─────────────────────────────────────────────────────────────────

  Future<List<StudentNoteModel>> getNotesByTeacher(int teacherId) async {
    return _ds.getNotesByTeacher(teacherId);
  }

  Future<StudentNoteModel> createNote({
    required int studentId,
    required int teacherId,
    required String note,
  }) async {
    return _ds.createNote(
      studentId: studentId,
      teacherId: teacherId,
      note: note,
    );
  }

  Future<void> deleteNote(int id) async {
    await _ds.deleteNote(id);
  }

  // ─── Memorization ─────────────────────────────────────────────────────────────────

  Future<void> submitMemorization({
    required int studentId,
    required int surahNumber,
    required int pagesDone,
    required String memorizationType,
  }) async {
    await _ds.submitMemorization(
      studentId: studentId,
      surahNumber: surahNumber,
      pagesDone: pagesDone,
      memorizationType: memorizationType,
    );
  }
}
