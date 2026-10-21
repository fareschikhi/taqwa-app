import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import '../models/user_model.dart';

class UserRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<UserModel> me() async {
    final response = await _dio.get('${ApiEndpoints.users}/me');
    return UserModel.fromJson(response.data);
  }

  /// Edits the signed-in user's own account. Only these three fields are
  /// accepted by the server; role and isActive are stripped there.
  Future<UserModel> updateMe({
    required String fullName,
    required String phone,
    required String email,
  }) async {
    final response = await _dio.patch(
      '${ApiEndpoints.users}/me',
      data: {'fullName': fullName, 'phone': phone, 'email': email},
    );
    return UserModel.fromJson(response.data);
  }

  /// The accounts already holding [phone] or [email] — whichever is given —
  /// leaving out [excludeUserId]. Phone and email may be shared, so this
  /// feeds a warning, not a refusal.
  Future<List<({String fullName, UserRole role})>> contactOwners({
    String? phone,
    String? email,
    int? excludeUserId,
  }) async {
    final response = await _dio.get(
      '${ApiEndpoints.users}/contact-owners',
      queryParameters: {
        'phone': ?phone,
        'email': ?email,
        'excludeUserId': ?excludeUserId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final rows = (data[phone != null ? 'phone' : 'email'] as List?) ?? const [];
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        (
          fullName: (row['fullName'] as String?) ?? '',
          role: UserModel.fromJson(row).role,
        ),
    ];
  }

  Future<void> setActive(int userId, bool isActive) async {
    await _dio.patch('${ApiEndpoints.users}/$userId', data: {'isActive': isActive});
  }
}
