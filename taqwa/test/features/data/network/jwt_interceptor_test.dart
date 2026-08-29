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
}
