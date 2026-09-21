import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:taqwa/core/storage/secure_storage.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';

class AuthRepository {
  final _datasource = AuthRemoteDatasource();
  final _storage = appSecureStorage;

  /// [identifier] is a phone number, or an email when it contains '@'.
  ///
  /// Caches the whole user, not just the role: checkAutoLogin restores the
  /// session from this entry before the network call returns, and it needs the
  /// role-specific ids to pick a home screen.
  Future<AuthResponseModel> login({
    required String identifier,
    required String password,
  }) async {
    final isEmail = identifier.contains('@');
    final result = await _datasource.login(
      phone: isEmail ? null : identifier,
      email: isEmail ? identifier : null,
      password: password,
    );
    await _storage.write(key: 'jwt_token', value: result.accessToken);
    await _storage.write(
      key: 'cached_user',
      value: jsonEncode(result.user.toJson()),
    );
    return result;
  }

  /// The token is intentionally left in place: the backend does not invalidate
  /// it, so the user stays signed in on the device they just used.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _datasource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
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
