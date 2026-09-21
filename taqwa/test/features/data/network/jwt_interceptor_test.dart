import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/network/interceptors/jwt_interceptor.dart';

Response responseWith(Map<String, List<String>> headers) => Response(
  requestOptions: RequestOptions(path: '/students'),
  headers: Headers.fromMap(headers),
);

void main() {
  test('reads a renewed token out of the response headers', () {
    final token = refreshedTokenFrom(
      responseWith({
        'x-refreshed-token': ['fresh.jwt.token'],
      }),
    );

    expect(token, 'fresh.jwt.token');
  });

  test('returns null when the server sent no renewal', () {
    expect(refreshedTokenFrom(responseWith({})), isNull);
  });

  test('ignores an empty header value', () {
    final token = refreshedTokenFrom(
      responseWith({
        'x-refreshed-token': [''],
      }),
    );

    expect(token, isNull);
  });

  test('still sends the request when the token store throws', () async {
    // An Android keystore entry that can no longer be decrypted — after an
    // app update, a reinstall or a restore from backup — makes the read
    // throw rather than return null. The request still has to go out: a
    // sign-in is exactly the case where there is no token to attach.
    final dio = _dioWith(
      JwtInterceptor(readToken: () async => throw Exception('keystore')),
    );

    final response = await dio
        .post<Map<String, dynamic>>('/auth/login')
        .timeout(const Duration(seconds: 2));

    expect(response.statusCode, 200);
  });

  test('still returns the response when storing a renewed token throws', () async {
    // The reply has already arrived and the call has already succeeded. A
    // store that refuses the renewed token costs the user that renewal, and
    // nothing else — it must not strand a response that is in hand.
    final dio = _dioWith(
      JwtInterceptor(
        readToken: () async => 'current.jwt.token',
        writeToken: (_) async => throw Exception('keystore'),
      ),
      responseHeaders: {
        'x-refreshed-token': ['fresh.jwt.token'],
      },
    );

    final response = await dio
        .get<Map<String, dynamic>>('/students')
        .timeout(const Duration(seconds: 2));

    expect(response.statusCode, 200);
  });
}

/// Answers every request immediately, so what these tests measure is the
/// interceptor chain and nothing else: if a request never completes here,
/// it is because the chain never handed it on.
class _InstantAdapter implements HttpClientAdapter {
  _InstantAdapter({this.extraHeaders = const {}});

  final Map<String, List<String>> extraHeaders;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"ok":true}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...extraHeaders,
    },
  );

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(
  JwtInterceptor interceptor, {
  Map<String, List<String>> responseHeaders = const {},
}) => Dio(BaseOptions(baseUrl: 'https://example.test/api'))
  ..httpClientAdapter = _InstantAdapter(extraHeaders: responseHeaders)
  ..interceptors.add(interceptor);
