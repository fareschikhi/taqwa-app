import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/datasources/device_remote_datasource.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

/// Records the request instead of sending it, so the datasource can be
/// exercised without a network or a server.
class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? captured;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      '{}',
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

  // JwtInterceptor reads flutter_secure_storage over a platform channel, and
  // there is no platform to answer it here. Null just means "no token".
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async => null);

  late _CaptureAdapter adapter;

  setUp(() {
    adapter = _CaptureAdapter();
    DioClient.instance.httpClientAdapter = adapter;
  });

  group('DeviceRemoteDatasource', () {
    test('registers a token against the signed-in user', () async {
      await DeviceRemoteDatasource().register('tok-abc');

      // The user is never named in the body: the backend claims the device
      // for whoever the bearer token belongs to.
      expect(adapter.captured!.method, 'POST');
      expect(adapter.captured!.path, '/devices/token');
      expect(adapter.captured!.data, {
        'token': 'tok-abc',
        'platform': 'android',
      });
    });

    test('releases a token on sign-out', () async {
      await DeviceRemoteDatasource().unregister('tok-abc');

      expect(adapter.captured!.method, 'DELETE');
      expect(adapter.captured!.path, '/devices/token');
      expect(adapter.captured!.data, {'token': 'tok-abc'});
    });

    test('sends the token in the body, never in the path', () async {
      // A registration token is long and contains characters that would need
      // escaping in a URL, and it does not belong in server access logs.
      await DeviceRemoteDatasource().register('tok/with+awkward=chars');

      expect(adapter.captured!.path, '/devices/token');
      expect(adapter.captured!.path, isNot(contains('awkward')));
    });
  });
}
