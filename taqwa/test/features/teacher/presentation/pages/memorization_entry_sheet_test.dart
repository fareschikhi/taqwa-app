import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/teacher_student_model.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/teacher/presentation/pages/memorization_entry_sheet.dart';

/// Answers every request with a fixed, caller-supplied JSON body, so the
/// sheet's hadith-history prefill fetch can be exercised without touching
/// the network. Mirrors the stub used by student_remote_datasource_test.dart.
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

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
);

/// Flutter's default test surface is a short 800x600 window, which is
/// narrower on height than this design's 390x844 basis. In production the
/// sheet is a full isScrollControlled bottom sheet on a real phone — always
/// far taller than 600 logical px — so it never hits this ceiling; only the
/// test's own tiny default surface does. Sized like login_validation_test.dart's
/// phone viewport so the sheet has the room it gets on a real device.
void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

TeacherStudentModel _student({bool tracksHadith = false}) =>
    TeacherStudentModel(
      id: 1,
      fullName: 'محمد بن صالح',
      isActive: true,
      tracksHadith: tracksHadith,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async => null);

  setUp(() {
    DioClient.instance.httpClientAdapter = _StubAdapter(jsonEncode([]));
  });

  testWidgets('offers no subject switch for a student without hadith tracking', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(MemorizationEntrySheet(student: _student(tracksHadith: false))),
    );
    await tester.pumpAndSettle();

    expect(find.text('القرآن'), findsNothing);
    expect(find.text('الحديث'), findsNothing);
    expect(find.text('السورة'), findsOneWidget);
  });

  testWidgets('offers a Quran/Hadith switch for a student with hadith tracking', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(MemorizationEntrySheet(student: _student(tracksHadith: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الحديث'), findsOneWidget);
    // Quran is the default subject, so the surah field is still the one shown.
    expect(find.text('السورة'), findsOneWidget);
  });

  testWidgets('switching to Hadith replaces the surah field with a text field', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(MemorizationEntrySheet(student: _student(tracksHadith: true))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();

    expect(find.text('السورة'), findsNothing);
    expect(find.text('الحديث'), findsWidgets); // segment label + field label
  });

  testWidgets(
    "prefills the hadith field with the student's most recent hadith",
    (tester) async {
      _setPhoneViewport(tester);
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode([
          {
            'id': 1,
            'studentId': 1,
            'surahNumber': null,
            'amountDone': 1,
            'memorizationType': 'MEMORIZING',
            'subject': 'HADITH',
            'hadithReference': 'حديث النية',
            'date': '2026-08-20T00:00:00.000Z',
            'recordedAt': '2026-08-20T10:00:00.000Z',
          },
        ]),
      );

      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student(tracksHadith: true))),
      );
      await tester.pumpAndSettle();

      // Only the segment option carries this text before switching, so it is
      // unambiguous to tap here.
      await tester.tap(find.text('الحديث'));
      await tester.pumpAndSettle();

      expect(find.text('حديث النية'), findsOneWidget);
    },
  );
}
