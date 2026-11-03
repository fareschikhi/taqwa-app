import 'package:dio/dio.dart';
import 'package:taqwa/core/utils/points_format.dart';
import '../models/points/points_summary_model.dart';
import '../network/dio_client.dart';

class PointsRepository {
  final Dio _dio = DioClient.instance;

  /// The signed-in teacher's, manager's or adult student's own points.
  Future<PointsSummaryModel> mine() => _summary('/points/me');

  /// A student's points. The server decides who may ask: the parent, the
  /// student himself, the staff of his halaqa, or the admin.
  Future<PointsSummaryModel> forStudent(int studentId) =>
      _summary('/points/student/$studentId');

  /// Any account's points — admin only.
  Future<PointsSummaryModel> forUser(int userId) =>
      _summary('/points/user/$userId');

  /// Every student's total in one halaqa, keyed by student id. A roster
  /// already has names and avatars, so only the total is kept.
  Future<Map<int, num>> forHalaqa(int halaqaId) async {
    final response = await _dio.get('/points/halaqa/$halaqaId');
    final rows = (response.data as List?) ?? const [];
    return {
      for (final row in rows.whereType<Map>())
        (row['studentId'] as num).toInt(): parsePoints(row['total']),
    };
  }

  /// A manual entry on [userId]'s points: positive adds, negative takes
  /// away. Rounded to two decimals first, the most the server accepts, so a
  /// float tail (0.1 + 0.2) is not refused. The server checks who may.
  Future<void> adjust({
    required int userId,
    required num amount,
    String? reason,
  }) async {
    final text = reason?.trim() ?? '';
    await _dio.post(
      '/points',
      data: {
        'userId': userId,
        'amount': double.parse(amount.toStringAsFixed(2)),
        if (text.isNotEmpty) 'reason': text,
      },
    );
  }

  /// Undoes one manual entry. The server refuses automatic ones, and staff
  /// removing someone else's.
  Future<void> remove(int entryId) => _dio.delete('/points/$entryId');

  Future<PointsSummaryModel> _summary(String path) async {
    final response = await _dio.get(path);
    return PointsSummaryModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
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
