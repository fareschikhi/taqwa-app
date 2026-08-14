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

  Future<void> setActive(int userId, bool isActive) async {
    await _dio.patch('${ApiEndpoints.users}/$userId', data: {'isActive': isActive});
  }
}
