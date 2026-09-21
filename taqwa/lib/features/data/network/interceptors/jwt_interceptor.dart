import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:taqwa/core/storage/secure_storage.dart';

/// Header the backend sets when it renews a token that is close to expiring.
const String kRefreshedTokenHeader = 'x-refreshed-token';

/// Pulled out of the interceptor so it can be tested without a Dio client.
/// Returns null when the server sent no renewal, or sent an empty one.
String? refreshedTokenFrom(Response response) {
  final value = response.headers.value(kRefreshedTokenHeader);
  return (value == null || value.isEmpty) ? null : value;
}

/// Reads the stored token. Injectable so the interceptor's behaviour when the
/// store fails can be tested without a keystore behind it.
typedef TokenReader = Future<String?> Function();

/// Stores a token the server renewed. Injectable for the same reason.
typedef TokenWriter = Future<void> Function(String token);

class JwtInterceptor extends Interceptor {
  JwtInterceptor({TokenReader? readToken, TokenWriter? writeToken})
    : _readToken = readToken ?? _readStoredToken,
      _writeToken = writeToken ?? _writeStoredToken;

  final TokenReader _readToken;
  final TokenWriter _writeToken;

  static const FlutterSecureStorage _storage = appSecureStorage;

  static Future<String?> _readStoredToken() => _storage.read(key: 'jwt_token');

  static Future<void> _writeStoredToken(String token) =>
      _storage.write(key: 'jwt_token', value: token);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    String? token;
    try {
      token = await _readToken();
    } catch (_) {
      // A store that cannot be read means there is no token to attach, not a
      // request that never leaves. Letting this throw strands the handler:
      // Dio's timeouts only start once a request is dispatched, so nothing
      // ever ends the call and the caller waits forever with no error. The
      // one request that matters here — signing in — carries no token anyway.
    }
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
      try {
        await _writeToken(refreshed);
      } catch (_) {
        // Losing the renewal costs the user nothing today — the token they
        // already hold is still valid, and the next request gets another
        // chance to renew it. Throwing here would strand a reply that has
        // already arrived, which costs them the screen they asked for.
      }
    }
    super.onResponse(response, handler);
  }
}
