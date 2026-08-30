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

  static String errorMessage(Object e) {
    if (e is DioException) {
      final msg = e.response?.data?['message'];
      if (msg is List) return msg.first;
      if (msg is String) return msg;
    }
    return 'حدث خطأ غير متوقع';
  }
}
