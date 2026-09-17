import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Header the backend sets when it renews a token that is close to expiring.
const String kRefreshedTokenHeader = 'x-refreshed-token';

/// Pulled out of the interceptor so it can be tested without a Dio client.
/// Returns null when the server sent no renewal, or sent an empty one.
String? refreshedTokenFrom(Response response) {
  final value = response.headers.value(kRefreshedTokenHeader);
  return (value == null || value.isEmpty) ? null : value;
}

class JwtInterceptor extends Interceptor {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // The session slides forward while the user is active, so an expiry is
    // only ever reached by not opening the app for a month.
    final refreshed = refreshedTokenFrom(response);
    if (refreshed != null) {
      await _storage.write(key: 'jwt_token', value: refreshed);
    }
    super.onResponse(response, handler);
  }
}
