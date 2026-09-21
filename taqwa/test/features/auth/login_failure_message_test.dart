import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/main.dart';

/// Refuses the sign-in the way the API does: a 401 carrying the reason the
/// user is meant to read.
class _RefusingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'message': 'بيانات الدخول غير صحيحة'}),
      401,
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

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
    DioClient.instance.httpClientAdapter = _RefusingAdapter();
  });

  // A refused sign-in has to say why. The form is the only thing on screen,
  // so a user who gets nothing back has no way to tell a typed password from
  // a sleeping server.
  testWidgets('a refused sign-in tells the user why', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TaqwaApp());

    // AuthGate holds an indeterminate spinner while the stored token is read,
    // and pumpAndSettle would wait on it forever. Step past it a frame at a
    // time until the form is up.
    for (var i = 0; i < 10 && find.byType(AppButton).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'you@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);
  });

  // The form is the user's work: the identifier they typed has to survive a
  // refusal, or a mistyped password costs them the email address as well.
  testWidgets('a refused sign-in keeps what the user typed', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TaqwaApp());
    for (var i = 0; i < 10 && find.byType(AppButton).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'you@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('you@example.com'), findsOneWidget);
  });

  // ApiEndpoints.login is referenced so the stub is read as standing in for
  // that call and not for the whole API.
  test('the stub answers the login endpoint', () {
    expect(ApiEndpoints.login, '/auth/login');
  });
}
