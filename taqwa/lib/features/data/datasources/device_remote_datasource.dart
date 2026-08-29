import 'package:dio/dio.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

/// Tells the API which device this is, so a notification written for the
/// signed-in user can be pushed to it.
///
/// The user is never named in the request. The backend claims the device for
/// whoever the bearer token belongs to, which is also what stops one account
/// registering a device on another's behalf.
class DeviceRemoteDatasource {
  final Dio _dio = DioClient.instance;

  Future<void> register(String token, {String platform = 'android'}) async {
    await _dio.post(
      '${ApiEndpoints.devices}/token',
      // In the body rather than the path: a registration token is long, holds
      // characters that would need escaping in a URL, and does not belong in
      // the server's access logs.
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregister(String token) async {
    await _dio.delete(
      '${ApiEndpoints.devices}/token',
      data: {'token': token},
    );
  }
}
