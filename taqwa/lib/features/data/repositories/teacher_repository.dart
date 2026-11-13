import 'package:dio/dio.dart';
import 'package:taqwa/features/data/models/teacher/teacher_payload_dto.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';
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
  Future<AttendanceSummaryModel> getAttendanceSummary(
    int teacherId, {
    int? halaqaId,
  }) async {
    return _ds.getAttendanceSummary(teacherId, halaqaId: halaqaId);
  }

  Future<List<RevisionNeededModel>> getRevisionNeeded(
    int teacherId, {
    int? halaqaId,
  }) async {
    return _ds.getRevisionNeeded(teacherId, halaqaId: halaqaId);
  }

  Future<MemorizationProgressSummaryModel> getMemorizationProgress(
    int teacherId, {
    int? halaqaId,
  }) async {
    return _ds.getMemorizationProgress(teacherId, halaqaId: halaqaId);
  }

  // ─── Students ──────────────────────────────────────────────────────────────

  Future<StudentListResponse> getStudents({
    required int teacherId,
    String? search,
    int page = 1,
    int limit = 30,
    bool? isActive,
    int? halaqaId,
  }) async {
    return _ds.getStudents(
      teacherId: teacherId,
      search: search,
      page: page,
      limit: limit,
      isActive: isActive,
      halaqaId: halaqaId,
    );
  }

  // ─── Attendance ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    return _ds.getAttendanceByDate(date);
  }

  Future<List<Map<String, dynamic>>> getWeeklyAttendanceRates() =>
      _ds.getWeeklyAttendanceRates();

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
    int? lateFee,
  }) async {
    await _ds.upsertAttendance(
      studentId: studentId,
      date: date,
      status: status,
      lateFee: lateFee,
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

  Future<StudentNoteModel> createBulkNote({
    required List<int> studentIds,
    required int teacherId,
    required String note,
  }) async {
    return _ds.createBulkNote(
      studentIds: studentIds,
      teacherId: teacherId,
      note: note,
    );
  }

  /// Only the text changes: the students a note went to are fixed when it is
  /// written, and editing it does not notify them again.
  Future<StudentNoteModel> updateNote({
    required int id,
    required String note,
  }) async {
    return _ds.updateNote(id: id, note: note);
  }

  Future<void> deleteNote(int id) async {
    await _ds.deleteNote(id);
  }

  // ─── Memorization ─────────────────────────────────────────────────────────────────

  /// Returns the row the server created, so the caller can show what is now
  /// on file without refetching the day. [surahNumber] is optional for a
  /// QURAN subject (an entry may record only an amount) and omitted for
  /// HADITH; [hadithReference] is required for HADITH and omitted for QURAN.
  Future<Map<String, dynamic>> submitMemorization({
    required int studentId,
    int? surahNumber,
    required num amountDone,
    required String memorizationType,
    String subject = 'QURAN',
    String? hadithReference,
    String? unit,
    int? ayahFrom,
    int? ayahTo,
    bool outsideSession = false,
  }) async {
    return _ds.submitMemorization(
      studentId: studentId,
      outsideSession: outsideSession,
      surahNumber: surahNumber,
      amountDone: amountDone,
      memorizationType: memorizationType,
      subject: subject,
      hadithReference: hadithReference,
      unit: unit,
      ayahFrom: ayahFrom,
      ayahTo: ayahTo,
    );
  }

  /// One Quran recitation applied to a whole group of students; see
  /// [TeacherRemoteDatasource.submitGroupMemorization] for the answer's shape.
  Future<Map<String, dynamic>> submitGroupMemorization({
    required List<int> studentIds,
    int? surahNumber,
    required num amountDone,
    required String memorizationType,
    String? unit,
    int? ayahFrom,
    int? ayahTo,
  }) async {
    return _ds.submitGroupMemorization(
      studentIds: studentIds,
      surahNumber: surahNumber,
      amountDone: amountDone,
      memorizationType: memorizationType,
      unit: unit,
      ayahFrom: ayahFrom,
      ayahTo: ayahTo,
    );
  }
}
