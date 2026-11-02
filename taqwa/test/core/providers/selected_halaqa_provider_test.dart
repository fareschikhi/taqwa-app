import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/selected_halaqa_provider.dart';
import 'package:taqwa/features/data/datasources/teacher_remote_datasource.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

/// Answers every request with [body] (or [status] with no body) and keeps
/// what was asked, so a test can check the query that went out.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.status = 200});

  final String body;
  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _halaqa(int id, String name) => {
  'id': id,
  'name': name,
  'teacherId': 3,
  '_count': {'students': 0},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // JwtInterceptor reads flutter_secure_storage over a platform channel that
  // a plain Dart test has nothing behind; null just means "no token".
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );

  group('selectedHalaqaProvider', () {
    test('selects the first of the teacher\'s halaqas', () async {
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode([_halaqa(4, 'الفجر'), _halaqa(7, 'العصر')]),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(selectedHalaqaProvider.notifier).load();

      final state = container.read(selectedHalaqaProvider);
      expect(state.isLoading, isFalse);
      expect(state.halaqas.map((h) => h.id), [4, 7]);
      expect(state.selected?.id, 4);
    });

    test('switches to the halaqa the teacher picks', () async {
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode([_halaqa(4, 'الفجر'), _halaqa(7, 'العصر')]),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedHalaqaProvider.notifier);
      await notifier.load();

      notifier.select(container.read(selectedHalaqaProvider).halaqas[1]);

      expect(container.read(selectedHalaqaProvider).selected?.id, 7);
    });

    test('a failed load leaves the tabs on every halaqa', () async {
      DioClient.instance.httpClientAdapter = _StubAdapter('{}', status: 500);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(selectedHalaqaProvider.notifier).load();

      final state = container.read(selectedHalaqaProvider);
      expect(state.isLoading, isFalse);
      expect(state.selected, isNull);
    });
  });

  group('inSelectedHalaqa', () {
    final fajr = HalaqaModel(id: 4, name: 'الفجر', teacherId: 3);

    test('lets everything through with no halaqa selected', () {
      expect(inSelectedHalaqa(9, null), isTrue);
      expect(inSelectedHalaqa(null, null), isTrue);
    });

    test('keeps to the selected halaqa', () {
      expect(inSelectedHalaqa(4, fajr), isTrue);
      expect(inSelectedHalaqa(9, fajr), isFalse);
      expect(inSelectedHalaqa(null, fajr), isFalse);
    });
  });

  group('TeacherRemoteDatasource halaqa filter', () {
    test('sends halaqaId only when a halaqa is given', () async {
      final adapter = _StubAdapter(
        jsonEncode({'present': 0, 'absent': 0, 'rate': 0, 'month': 10}),
      );
      DioClient.instance.httpClientAdapter = adapter;
      final ds = TeacherRemoteDatasource();

      await ds.getAttendanceSummary(3, halaqaId: 7);
      await ds.getAttendanceSummary(3);

      expect(adapter.requests[0].queryParameters, {'halaqaId': 7});
      expect(adapter.requests[1].queryParameters, isEmpty);
    });

    test('narrows the roster to the given halaqa', () async {
      final adapter = _StubAdapter(
        jsonEncode({'data': [], 'total': 0, 'page': 1, 'limit': 100}),
      );
      DioClient.instance.httpClientAdapter = adapter;

      await TeacherRemoteDatasource().getStudents(teacherId: 3, halaqaId: 7);

      expect(adapter.requests.single.queryParameters['halaqaId'], 7);
    });
  });
}
