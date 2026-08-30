import 'package:dio/dio.dart';
import '../models/fine/fine_summary_model.dart';
import '../network/dio_client.dart';

class FineRepository {
  final Dio _dio = DioClient.instance;

  Future<FineSummaryModel> forStudent(int studentId) async {
    final response = await _dio.get('/fines/student/$studentId');
    return FineSummaryModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Every adult student's balance in one halaqa, keyed by student id.
  ///
  /// `GET /fines/halaqa/:id` returns a row per student — name and avatar
  /// included — but a roster screen already has those from its own student
  /// list, so only the balance is worth folding out of the response here.
  Future<Map<int, int>> forHalaqa(int halaqaId) async {
    final response = await _dio.get('/fines/halaqa/$halaqaId');
    final rows = (response.data as List?) ?? const [];
    return {
      for (final row in rows.whereType<Map>())
        (row['studentId'] as num).toInt():
            (row['balance'] as num?)?.toInt() ?? 0,
    };
  }

  /// Records a manual charge or reduction. [amount] is always positive —
  /// [kind] ('CHARGE' or 'REDUCTION') carries the direction, never the sign.
  Future<void> adjust({
    required int studentId,
    required String kind,
    required int amount,
    String? reason,
  }) async {
    await _dio.post(
      '/fines',
      data: {
        'studentId': studentId,
        'kind': kind,
        'amount': amount,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }
}
