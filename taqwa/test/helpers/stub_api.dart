import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

/// A reply from [StubApi]: a status code and a JSON-encodable body.
typedef StubReply = (int status, Object? body);

/// Stands in for the server: every request the app's [DioClient] makes is
/// recorded in [requests] and answered by [reply], so no test ever reaches a
/// network. Install with [StubApi.install].
class StubApi implements HttpClientAdapter {
  StubApi(this.reply);

  /// Answers one request. Unmatched paths should get a 404 so a forgotten
  /// route fails loudly rather than quietly returning nothing.
  StubReply Function(RequestOptions request) reply;

  final List<RequestOptions> requests = [];

  /// The requests sent with [method] (e.g. 'POST') to a path containing
  /// [pathPart].
  List<RequestOptions> sent(String method, String pathPart) => requests
      .where((r) => r.method == method && r.path.contains(pathPart))
      .toList();

  /// Points [DioClient] at a new stub and silences the secure-storage
  /// channel the JWT interceptor reads (no token, no platform).
  static StubApi install(StubReply Function(RequestOptions request) reply) {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    final api = StubApi(reply);
    DioClient.instance.httpClientAdapter = api;
    return api;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = reply(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
