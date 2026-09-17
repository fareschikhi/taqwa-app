import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

/// Answers every request the same way, so a test can say what the server
/// thinks of the stored token and nothing else.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter.status(this.statusCode) : failure = null;
  _FixedAdapter.unreachable(this.failure) : statusCode = null;

  final int? statusCode;
  final DioExceptionType? failure;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(
      '{}',
      statusCode!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _cachedParent() => jsonEncode(
  UserModel(id: 1, fullName: 'أم خالد', role: UserRole.parent).toJson(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  late Map<String, String> store;

  setUp(() {
    store = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return store[key];
            case 'write':
              store[key!] = args['value'] as String;
              return null;
            case 'delete':
              store.remove(key);
              return null;
            case 'containsKey':
              return store.containsKey(key);
            case 'readAll':
              return store;
          }
          return null;
        });
  });

  test('starts out restoring, so a launch cannot flash the login form', () {
    store['jwt_token'] = 'stored.jwt.token';
    DioClient.instance.httpClientAdapter = _FixedAdapter.status(200);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Read synchronously: checkAutoLogin runs in a microtask, so this is the
    // state the very first frame is built from.
    expect(container.read(authProvider).isLoading, isTrue);
  });

  test('signs the user out when the server refuses the stored token', () async {
    store['jwt_token'] = 'expired.jwt.token';
    store['cached_user'] = _cachedParent();
    DioClient.instance.httpClientAdapter = _FixedAdapter.status(401);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(authProvider);
    await container.read(authProvider.notifier).checkAutoLogin();

    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(store.containsKey('jwt_token'), isFalse);
    expect(store.containsKey('cached_user'), isFalse);
  });

  test('keeps the session when the server cannot be reached', () async {
    store['jwt_token'] = 'good.jwt.token';
    store['cached_user'] = _cachedParent();
    DioClient.instance.httpClientAdapter = _FixedAdapter.unreachable(
      DioExceptionType.connectionError,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(authProvider);
    await container.read(authProvider.notifier).checkAutoLogin();

    // Offline is not a verdict on the token. Clearing it here would sign a
    // parent out for walking into a basement.
    expect(container.read(authProvider).isAuthenticated, isTrue);
    expect(container.read(authProvider).user?.fullName, 'أم خالد');
    expect(store['jwt_token'], 'good.jwt.token');
  });
}
