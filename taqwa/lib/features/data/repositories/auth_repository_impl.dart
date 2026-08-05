import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';

class AuthRepository {
  final _datasource = AuthRemoteDatasource();
  final _storage = const FlutterSecureStorage();

  Future<AuthResponseModel> login({
    required String phone,
    required String password,
  }) async {
    final result = await _datasource.login(phone: phone, password: password);
    await _storage.write(key: 'jwt_token', value: result.accessToken);
    await _storage.write(key: 'user_role', value: result.user.role);
    return result;
  }

  Future<void> logout() async => _storage.deleteAll();
}
