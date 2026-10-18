import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/constants/hadith_books.dart';
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

TeacherStudentModel _student({List<String> hadithBooks = const []}) =>
    TeacherStudentModel(
      id: 1,
      fullName: 'محمد بن صالح',
      isActive: true,
      hadithBooks: hadithBooks,
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
      _host(MemorizationEntrySheet(student: _student())),
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
      _host(MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks))),
    );
    await tester.pumpAndSettle();

    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الحديث'), findsOneWidget);
    // Quran is the default subject, so the surah field is still the one shown.
    expect(find.text('السورة'), findsOneWidget);
  });

  testWidgets('switching to Hadith replaces the surah field with a book picker', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();

    expect(find.text('السورة'), findsNothing);
    expect(find.text('الكتاب'), findsOneWidget);
    expect(find.text('اختر الكتاب...'), findsOneWidget);

    await tester.tap(find.text('اختر الكتاب...'));
    await tester.pumpAndSettle();

    for (final book in kHadithBooks) {
      expect(find.text(book), findsWidgets);
    }
  });

  testWidgets('lists only the books the admin assigned to the student', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final assigned = [kHadithBooks[0], kHadithBooks[3]];
    await tester.pumpWidget(
      _host(MemorizationEntrySheet(student: _student(hadithBooks: assigned))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختر الكتاب...'));
    await tester.pumpAndSettle();

    for (final book in kHadithBooks) {
      expect(
        find.text(book),
        assigned.contains(book) ? findsWidgets : findsNothing,
      );
    }
  });

  testWidgets('selects the only assigned book without asking', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(
        MemorizationEntrySheet(
          student: _student(hadithBooks: [kHadithBooks[2]]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();

    expect(find.text(kHadithBooks[2]), findsOneWidget);
    expect(find.text('اختر الكتاب...'), findsNothing);
  });

  testWidgets(
    'leaves the book picker empty when the last book is no longer assigned',
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
            'hadithReference': kHadithBooks[2],
            'date': '2026-08-20T00:00:00.000Z',
            'recordedAt': '2026-08-20T10:00:00.000Z',
          },
        ]),
      );

      await tester.pumpWidget(
        _host(
          MemorizationEntrySheet(
            student: _student(hadithBooks: [kHadithBooks[0], kHadithBooks[1]]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الحديث'));
      await tester.pumpAndSettle();

      expect(find.text(kHadithBooks[2]), findsNothing);
      expect(find.text('اختر الكتاب...'), findsOneWidget);
    },
  );

  testWidgets(
    'leaves the book picker empty when the last hadith was free text',
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
        _host(MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الحديث'));
      await tester.pumpAndSettle();

      expect(find.text('حديث النية'), findsNothing);
      expect(find.text('اختر الكتاب...'), findsOneWidget);
    },
  );

  testWidgets(
    "preselects the book of the student's most recent hadith",
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
            'hadithReference': 'عُمدة الأحكام',
            'date': '2026-08-20T00:00:00.000Z',
            'recordedAt': '2026-08-20T10:00:00.000Z',
          },
        ]),
      );

      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks))),
      );
      await tester.pumpAndSettle();

      // Only the segment option carries this text before switching, so it is
      // unambiguous to tap here.
      await tester.tap(find.text('الحديث'));
      await tester.pumpAndSettle();

      expect(find.text('عُمدة الأحكام'), findsOneWidget);
      expect(find.text('اختر الكتاب...'), findsNothing);
    },
  );

  testWidgets(
    'does not overflow when a keyboard opens over the hadith form on a small phone',
    (tester) async {
      // iPhone-SE-class viewport: 750x1334 physical @2x devicePixelRatio,
      // i.e. 375x667 logical — a small phone, not the roomier one
      // _setPhoneViewport uses elsewhere in this file.
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الحديث'));
      await tester.pumpAndSettle();

      // Simulates a normal ~300dp keyboard covering the bottom of the
      // screen — the inset the OS applies while a field is focused —
      // without needing a real text-input platform channel.
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      await tester.pumpAndSettle();

      // A RenderFlex overflow is reported through FlutterError, which the
      // test framework records as an exception on the tester rather than
      // throwing synchronously — so this is what actually catches the
      // regression the fix addresses.
      expect(tester.takeException(), isNull);
      // The submit button must still be part of the tree (reachable by
      // scrolling), not pushed out of the layout entirely.
      expect(find.text('تسجيل'), findsOneWidget);
    },
  );
}
