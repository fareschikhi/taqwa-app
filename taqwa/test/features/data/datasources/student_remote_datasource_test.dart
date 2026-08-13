import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/datasources/student_remote_datasource.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

/// Answers every request with a fixed, caller-supplied JSON body, so the
/// datasource can be exercised without touching the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // DioClient wires JwtInterceptor onto every request, and that interceptor
  // reads flutter_secure_storage over a platform channel. There is no
  // platform to answer it in a plain Dart test, so without a stub the call
  // hangs until the test times out; returning null just means "no token".
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async => null);

  group('StudentRemoteDatasource.getCount', () {
    test('returns the backend total, not the page size', () async {
      // The backend paginates and caps `data` at the page's `limit`, but
      // still reports the real `total` alongside it. A dashboard tile that
      // reads student count from `data.length` instead of `total` silently
      // caps at the page size once the school has more students than that.
      final payload = jsonEncode({
        'data': List.generate(
          3,
          (i) => {
            'id': i + 1,
            'fullName': 'Student $i',
            'birthDate': '2010-01-01',
            'address': 'Somewhere',
          },
        ),
        'total': 63,
        'page': 1,
        'limit': 50,
      });

      // DioClient.instance is a singleton, so the stub must be assigned onto
      // that same instance rather than a fresh Dio().
      DioClient.instance.httpClientAdapter = _StubAdapter(payload);

      final count = await StudentRemoteDatasource().getCount();

      expect(count, 63);
    });
  });
}
