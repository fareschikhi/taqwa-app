import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student/student_model.dart';
import '../models/teacher/teacher_model.dart';
import '../models/halaqa_model.dart';
import '../models/attendance_model.dart';
import '../models/memorization_model.dart';
import '../models/evaluation_model.dart';
import '../models/notification_model.dart';
import '../network/dio_client.dart';
import '../network/api_endpoints.dart';

final dioProvider = Provider<Dio>((ref) => DioClient.instance);

// --- Students Providers ---
final studentsProvider = FutureProvider<List<StudentModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.students);
  return (response.data as List).map((e) => StudentModel.fromJson(e)).toList();
});

final studentProfileProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, id) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('${ApiEndpoints.students}/$id/profile');
    return response.data;
  },
);

// --- Teachers Providers ---
final teachersProvider = FutureProvider<List<TeacherModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.teachers);
  return (response.data as List).map((e) => TeacherModel.fromJson(e)).toList();
});

final teacherDetailProvider = FutureProvider.family<TeacherModel, int>((
  ref,
  id,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiEndpoints.teachers}/$id');
  return TeacherModel.fromJson(response.data);
});

// --- Halaqas Providers ---
final halaqasProvider = FutureProvider<List<HalaqaModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.halaqas);
  return (response.data as List).map((e) => HalaqaModel.fromJson(e)).toList();
});

final halaqaDetailProvider = FutureProvider.family<HalaqaModel, int>((
  ref,
  id,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiEndpoints.halaqas}/$id');
  return HalaqaModel.fromJson(response.data);
});

// --- Attendance Providers ---
final studentAttendanceProvider =
    FutureProvider.family<List<AttendanceModel>, int>((ref, studentId) async {
      final dio = ref.watch(dioProvider);
      final response = await dio.get(
        '${ApiEndpoints.attendance}/student/$studentId',
      );
      return (response.data as List)
          .map((e) => AttendanceModel.fromJson(e))
          .toList();
    });

final studentAttendanceSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, studentId) async {
      final dio = ref.watch(dioProvider);
      final response = await dio.get(
        '${ApiEndpoints.attendance}/student/$studentId/summary',
      );
      return response.data;
    });

// --- Memorization Providers ---
final studentMemorizationProvider =
    FutureProvider.family<List<MemorizationModel>, int>((ref, studentId) async {
      final dio = ref.watch(dioProvider);
      final response = await dio.get(
        '${ApiEndpoints.memorization}/student/$studentId',
      );
      return (response.data as List)
          .map((e) => MemorizationModel.fromJson(e))
          .toList();
    });

final studentMemorizationProgressProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, studentId) async {
      final dio = ref.watch(dioProvider);
      final response = await dio.get(
        '${ApiEndpoints.memorization}/student/$studentId/progress',
      );
      return response.data;
    });

// --- Evaluations Providers ---
final studentEvaluationsProvider =
    FutureProvider.family<List<EvaluationModel>, int>((ref, studentId) async {
      final dio = ref.watch(dioProvider);
      final response = await dio.get(
        '${ApiEndpoints.evaluations}/student/$studentId',
      );
      return (response.data as List)
          .map((e) => EvaluationModel.fromJson(e))
          .toList();
    });

// --- Notifications Providers ---
final myNotificationsProvider = FutureProvider<List<NotificationModel>>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiEndpoints.notifications}/me');
  return (response.data as List)
      .map((e) => NotificationModel.fromJson(e))
      .toList();
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiEndpoints.notifications}/me/unread');
  return response.data['count'] ?? 0;
});

// --- Operations Helper class ---
class FeatureOperations {
  final Dio _dio;
  FeatureOperations(this._dio);

  Future<void> saveAttendance({
    required int studentId,
    required String date,
    required String status,
    String? notes,
  }) async {
    await _dio.post(
      ApiEndpoints.attendance,
      data: {
        'studentId': studentId,
        'date': date,
        'status': status,
        'notes': notes,
      },
    );
  }

  Future<void> saveMemorization({
    required int studentId,
    required int surahNumber,
    required String surahName,
    required int fromAyah,
    required int toAyah,
    double? memorizationScore,
    double? revisionScore,
    String? notes,
  }) async {
    await _dio.post(
      ApiEndpoints.memorization,
      data: {
        'studentId': studentId,
        'surahNumber': surahNumber,
        'surahName': surahName,
        'fromAyah': fromAyah,
        'toAyah': toAyah,
        'memorizationScore': memorizationScore,
        'revisionScore': revisionScore,
        'notes': notes,
      },
    );
  }

  Future<void> saveEvaluation({
    required int studentId,
    required int teacherId,
    double? memorizationScore,
    double? tajweedScore,
    double? fluencyScore,
    double? disciplineScore,
    double? overallScore,
    String? notes,
  }) async {
    await _dio.post(
      ApiEndpoints.evaluations,
      data: {
        'studentId': studentId,
        'teacherId': teacherId,
        'memorizationScore': memorizationScore,
        'tajweedScore': tajweedScore,
        'fluencyScore': fluencyScore,
        'disciplineScore': disciplineScore,
        'overallScore': overallScore,
        'notes': notes,
      },
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.post('${ApiEndpoints.notifications}/me/read-all');
  }

  Future<void> markNotificationRead(int id) async {
    await _dio.patch('${ApiEndpoints.notifications}/$id/read');
  }

  Future<void> createHalaqa({
    required String name,
    String? description,
    String? level,
    required int teacherId,
    List<int>? studentIds,
  }) async {
    await _dio.post(
      ApiEndpoints.halaqas,
      data: {
        'name': name,
        'description': description,
        'level': level,
        'teacherId': teacherId,
        'studentIds': studentIds,
      },
    );
  }

  Future<void> createStudent({
    required String fullName,
    String? email,
    String? phone,
    required String password,
    String? birthDate,
    int? teacherId,
  }) async {
    await _dio.post(
      ApiEndpoints.students,
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'birthDate': birthDate,
        'teacherId': teacherId,
      },
    );
  }

  Future<void> createTeacher({
    required String fullName,
    String? email,
    String? phone,
    required String password,
    String? specialization,
    String? hireDate,
  }) async {
    await _dio.post(
      ApiEndpoints.teachers,
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'specialization': specialization,
        'hireDate': hireDate,
      },
    );
  }

  Future<void> createParent({
    required String fullName,
    String? email,
    String? phone,
    required String password,
    String? address,
    List<int>? childrenIds,
  }) async {
    await _dio.post(
      ApiEndpoints.parents,
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'address': address,
        'childrenIds': childrenIds,
      },
    );
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await _dio.get('${ApiEndpoints.users}/stats');
    return response.data;
  }
}

final featureOperationsProvider = Provider<FeatureOperations>((ref) {
  final dio = ref.watch(dioProvider);
  return FeatureOperations(dio);
});
