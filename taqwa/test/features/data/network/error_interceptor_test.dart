import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/network/interceptors/error_interceptor.dart';

/// Fails every request with a caller-supplied [DioException], so the
/// interceptor can be exercised without touching the network.
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.buildError);

  final DioException Function(RequestOptions options) buildError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw buildError(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Runs one request through [ErrorInterceptor] and returns the message it
/// attached to the failure.
Future<String?> messageFor(DioException Function(RequestOptions) buildError) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
    ..httpClientAdapter = _FailingAdapter(buildError);
  dio.interceptors.add(ErrorInterceptor());

  try {
    await dio.get<void>('/anything');
    fail('the adapter should have thrown');
  } on DioException catch (e) {
    return e.error as String?;
  }
}

void main() {
  group('ErrorInterceptor', () {
    // A timeout means the server accepted the socket but answered too slowly.
    // Telling the user to check their network sends them to fix something that
    // is not broken, so timeouts and genuine connection failures must not share
    // a message.
    test('a timeout does not blame the network', () async {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        final message = await messageFor(
          (options) => DioException(requestOptions: options, type: type),
        );

        expect(message, isNotNull, reason: 'no message produced for $type');
        expect(
          message,
          isNot(contains('الشبكة')),
          reason: '$type told the user to check their network',
        );
      }
    });

    test('an unreachable host does blame the network', () async {
      final message = await messageFor(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      expect(message, contains('الشبكة'));
    });

    test('a server-supplied message is passed through unchanged', () async {
      final message = await messageFor(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 401,
            data: {'message': 'بيانات الدخول غير صحيحة'},
          ),
        ),
      );

      expect(message, 'بيانات الدخول غير صحيحة');
    });

    test('a list of validation errors is joined', () async {
      final message = await messageFor(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 400,
            data: {
              'message': ['first problem', 'second problem'],
            },
          ),
        ),
      );

      expect(message, 'first problem\nsecond problem');
    });
  });
}
