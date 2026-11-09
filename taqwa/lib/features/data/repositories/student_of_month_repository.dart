import 'package:dio/dio.dart';
import '../models/student_of_month_model.dart';
import '../network/dio_client.dart';

class StudentOfMonthRepository {
  final Dio _dio = DioClient.instance;

  /// The validated picks for every halaqa the signed-in user reaches. A
  /// halaqa whose teacher has not validated yet is simply missing.
  Future<List<StudentOfMonthModel>> mine() async {
    final response = await _dio.get('/student-of-month/mine');
    return ((response.data as List?) ?? const [])
        .whereType<Map>()
        .map((r) => StudentOfMonthModel.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// The teacher's halaqas still waiting for last month's pick.
  Future<List<PendingStudentOfMonth>> pending() async {
    final response = await _dio.get('/student-of-month/pending');
    return ((response.data as List?) ?? const [])
        .whereType<Map>()
        .map(
          (r) => PendingStudentOfMonth.fromJson(Map<String, dynamic>.from(r)),
        )
        .toList();
  }

  Future<void> select({required int halaqaId, required int studentId}) =>
      _dio.post(
        '/student-of-month',
        data: {'halaqaId': halaqaId, 'studentId': studentId},
      );

  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      if (msg is String) return msg;
      return 'تعذّر الاتصال بالخادم، حاول مجدداً';
    }
    return 'حدث خطأ غير متوقع';
  }
}
