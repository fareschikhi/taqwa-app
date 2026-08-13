import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import '../models/auth_response_model.dart';

class AuthRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<AuthResponseModel> login({
    String? phone,
    String? email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {'phone': ?phone, 'email': ?email, 'password': password},
    );
    return AuthResponseModel.fromJson(response.data);
  }
}
