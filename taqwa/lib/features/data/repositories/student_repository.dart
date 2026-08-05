import 'package:dio/dio.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';
import '../datasources/student_remote_datasource.dart';
import '../models/student/student_model.dart';
import '../models/attendance_summary_model.dart';

class StudentRepository {
  final _ds = StudentRemoteDatasource();

  Future<List<StudentModel>> getAllStudents() => _ds.getAll();

  Future<StudentModel> getStudent(int id) => _ds.getOne(id);

  Future<StudentModel> createStudent(StudentPayloadDto student) =>
      _ds.create(student);

  Future<StudentModel> updateStudent(int id, Map<String, dynamic> data) =>
      _ds.update(id, data);

  Future<void> deleteStudent(int id) => _ds.delete(id);

  Future<Map<String, dynamic>> getProfile(int id) => _ds.getProfile(id);

  Future<AttendanceSummaryModel> getAttendanceSummary(int studentId) =>
      _ds.getAttendanceSummary(studentId);

  Future<List<Map<String, dynamic>>> getAttendanceHistory(int studentId) =>
      _ds.getAttendanceHistory(studentId);

  Future<Map<String, dynamic>> getMemorizationProgress(int studentId) =>
      _ds.getMemorizationProgress(studentId);

  Future<List<Map<String, dynamic>>> getMemorizationHistory(int studentId) =>
      _ds.getMemorizationHistory(studentId);

  /// Wraps DioException into a readable message
  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is List && msg.isNotEmpty) return msg.join('\n');
        if (msg is String && msg.isNotEmpty) return msg;
        if (data['error'] is String) return data['error'];
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
      return e.message ?? 'حدث خطأ في الاتصال بالخادم';
    }
    return e.toString();
  }
}
