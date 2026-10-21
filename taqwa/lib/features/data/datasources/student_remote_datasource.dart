import 'package:dio/dio.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import '../models/student/student_model.dart';
import '../models/attendance_summary_model.dart';
import '../models/student_note_model.dart';

class StudentRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<List<StudentModel>> getAll() async {
    final rows = await getAllRaw();
    return rows.map(StudentModel.fromJson).toList();
  }

  /// Every student, not just the first page: `/students` paginates (50 by
  /// default), so this walks the pages until it has collected `total` rows.
  /// Callers that group or filter the whole roster client-side need this —
  /// a single unpaged call silently drops everyone past the first page.
  Future<List<Map<String, dynamic>>> getAllRaw() async {
    const pageSize = 200;
    final rows = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final res = await _dio.get(
        '/students',
        queryParameters: {'page': page, 'limit': pageSize},
      );
      final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
      rows.addAll(data);
      final total = (res.data['total'] as num?)?.toInt() ?? rows.length;
      if (data.isEmpty || rows.length >= total) return rows;
    }
  }

  /// One page of the roster in section order — enrolled students by halaqa,
  /// then the unassigned — for a list that loads more as it scrolls. The raw
  /// response also carries `total` and `halaqaCounts`, each section's full
  /// size, so a header need not wait for every page to know its count.
  Future<Map<String, dynamic>> getGroupedPage({
    required int page,
    required int limit,
    String? search,
    int? halaqaId,
  }) async {
    final res = await _dio.get(
      '/students',
      queryParameters: {
        'groupByHalaqa': 'true',
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
        if (halaqaId != null) 'halaqaId': halaqaId,
      },
    );
    return res.data as Map<String, dynamic>;
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

  /// Every note written about the student, newest first. The profile only
  /// carries the latest five.
  Future<List<StudentNoteModel>> getNotes(int studentId) async {
    final res = await _dio.get(
      '${ApiEndpoints.studentNotes}/student/$studentId',
    );
    return (res.data as List)
        .map((e) => StudentNoteModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
