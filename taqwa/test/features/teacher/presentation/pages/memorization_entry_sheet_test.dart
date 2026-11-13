import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/constants/hadith_books.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/features/data/models/teacher_student_model.dart';
import 'package:taqwa/features/data/network/dio_client.dart';
import 'package:taqwa/features/teacher/presentation/pages/memorization_entry_sheet.dart';

/// Answers every request with a fixed, caller-supplied JSON body, so the
/// sheet's hadith-history prefill fetch can be exercised without touching
/// the network. Mirrors the stub used by student_remote_datasource_test.dart.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.onRequest});
  final String body;

  /// Sees every request, so a test can check what the sheet sent.
  final void Function(RequestOptions options)? onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest?.call(options);
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

  testWidgets(
    'offers no subject switch for a student without hadith tracking',
    (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();

      expect(find.text('القرآن'), findsNothing);
      expect(find.text('الحديث'), findsNothing);
      expect(find.text('السورة (اختياري)'), findsOneWidget);
    },
  );

  testWidgets(
    'offers a Quran/Hadith switch for a student with hadith tracking',
    (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(
        _host(
          MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('القرآن'), findsOneWidget);
      expect(find.text('الحديث'), findsOneWidget);
      // Quran is the default subject, so the surah field is still the one shown.
      expect(find.text('السورة (اختياري)'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to Hadith replaces the surah field with a book picker',
    (tester) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(
        _host(
          MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الحديث'));
      await tester.pumpAndSettle();

      expect(find.text('السورة (اختياري)'), findsNothing);
      expect(find.text('الكتاب'), findsOneWidget);
      expect(find.text('اختر الكتاب...'), findsOneWidget);

      await tester.tap(find.text('اختر الكتاب...'));
      await tester.pumpAndSettle();

      for (final book in kHadithBooks) {
        expect(find.text(book), findsWidgets);
      }
    },
  );

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

  testWidgets('selects the only assigned book without asking', (tester) async {
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
        _host(
          MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الحديث'));
      await tester.pumpAndSettle();

      expect(find.text('حديث النية'), findsNothing);
      expect(find.text('اختر الكتاب...'), findsOneWidget);
    },
  );

  testWidgets("preselects the book of the student's most recent hadith", (
    tester,
  ) async {
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
      _host(
        MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
      ),
    );
    await tester.pumpAndSettle();

    // Only the segment option carries this text before switching, so it is
    // unambiguous to tap here.
    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();

    expect(find.text('عُمدة الأحكام'), findsOneWidget);
    expect(find.text('اختر الكتاب...'), findsNothing);
  });

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
        _host(
          MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
        ),
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
  testWidgets('the page count can be typed, including a half page', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(_host(MemorizationEntrySheet(student: _student())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(find.textContaining('نصف صفحة'), findsOneWidget);

    await tester.enterText(field, '3.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('3.5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('4.5'), findsOneWidget);
  });

  testWidgets('a revision is counted in pages and takes a half', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(_host(MemorizationEntrySheet(student: _student())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('جمع'));
    await tester.pumpAndSettle();

    expect(find.text('عدد الصفحات'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('2.5'), findsOneWidget);
  });

  testWidgets('a typed amount above the mushaf is brought down to it', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(_host(MemorizationEntrySheet(student: _student())));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('604'), findsOneWidget);
  });

  testWidgets('counting by hizb starts at ten pages and steps by ten', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(_host(MemorizationEntrySheet(student: _student())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حزب'));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);

    // Back to pages: one page, stepping by one.
    await tester.tap(find.text('صفحات'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('counting by surah starts at its pages and steps by one', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(_host(MemorizationEntrySheet(student: _student())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('سورة'));
    await tester.pumpAndSettle();
    // No surah picked yet, so there is nothing to count but one page.
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('بدون تحديد السورة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آل عمران').last);
    await tester.pumpAndSettle();
    expect(find.text('27'), findsOneWidget); // pages 50-76

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('26'), findsOneWidget);

    // Picking another surah follows it to its own length.
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النساء').last);
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget); // pages 77-106
  });

  testWidgets('a hadith entry counts hadiths by default, whole only', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(
        MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();
    // Hadith offers its own two units instead of the Quran's surah/hizb.
    expect(find.text('طريقة العد'), findsOneWidget);
    expect(find.text('أحاديث'), findsOneWidget);
    expect(find.text('حزب'), findsNothing);
    expect(find.text('عدد الأحاديث'), findsOneWidget);
    expect(find.textContaining('نصف صفحة'), findsNothing);
  });

  testWidgets('a hadith entry can be counted in half pages', (tester) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(
        MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صفحات'));
    await tester.pumpAndSettle();

    expect(find.text('عدد الصفحات'), findsOneWidget);
    expect(find.textContaining('نصف صفحة'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('2.5'), findsOneWidget);

    // Back to hadiths: a half has no meaning there, so the count restarts.
    await tester.tap(find.text('أحاديث'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('sends the chosen hadith unit with the entry', (tester) async {
    _setPhoneViewport(tester);
    final sent = <Map<String, dynamic>>[];
    DioClient.instance.httpClientAdapter = _StubAdapter(
      jsonEncode({'id': 5}),
      onRequest: (options) {
        if (options.method == 'POST') {
          sent.add(Map<String, dynamic>.from(options.data as Map));
        }
      },
    );
    await tester.pumpWidget(
      _host(
        MemorizationEntrySheet(
          student: _student(hadithBooks: [kHadithBooks[0]]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صفحات'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل'));
    await tester.pumpAndSettle();

    expect(sent.single['subject'], 'HADITH');
    expect(sent.single['unit'], 'PAGE');
  });

  // The teacher who counts a book in pages keeps doing so: the unit follows
  // the student's last hadith entry.
  testWidgets("preselects the unit of the student's last hadith entry", (
    tester,
  ) async {
    _setPhoneViewport(tester);
    DioClient.instance.httpClientAdapter = _StubAdapter(
      jsonEncode([
        {
          'subject': 'HADITH',
          'unit': 'PAGE',
          'hadithReference': kHadithBooks[0],
          'memorizationType': 'MEMORIZING',
          'amountDone': 2,
          'date': '2026-10-20',
        },
      ]),
    );
    await tester.pumpWidget(
      _host(
        MemorizationEntrySheet(student: _student(hadithBooks: kHadithBooks)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الحديث'));
    await tester.pumpAndSettle();
    expect(find.text('عدد الصفحات'), findsOneWidget);
  });

  group('counting by ayahs', () {
    List<Map<String, dynamic>> captureSent() {
      final sent = <Map<String, dynamic>>[];
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode({'id': 5}),
        onRequest: (options) {
          if (options.method == 'POST') {
            sent.add(Map<String, dynamic>.from(options.data as Map));
          }
        },
      );
      return sent;
    }

    Future<void> openAyahsFor(WidgetTester tester, String surah) async {
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('آيات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بدون تحديد السورة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(surah).last);
      await tester.pumpAndSettle();
    }

    // Row order is left to right: «إلى آية» first, «من آية» on the right.
    Finder toField() => find.byType(TextField).at(0);
    Finder fromField() => find.byType(TextField).at(1);

    testWidgets('sends the range with its ayah count', (tester) async {
      _setPhoneViewport(tester);
      final sent = captureSent();
      await openAyahsFor(tester, 'الفاتحة');

      await tester.enterText(fromField(), '2');
      await tester.enterText(toField(), '7');
      await tester.pumpAndSettle();
      expect(find.textContaining('المجموع: 6 آية'), findsOneWidget);

      await tester.tap(find.text('حفظ'));
      await tester.tap(find.text('تسجيل'));
      await tester.pumpAndSettle();

      expect(sent.single['unit'], 'AYAH');
      expect(sent.single['surahNumber'], 1);
      expect(sent.single['ayahFrom'], 2);
      expect(sent.single['ayahTo'], 7);
      expect(sent.single['amountDone'], 6);
    });

    testWidgets('flags an ayah past the end of the surah and sends nothing', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      final sent = captureSent();
      await openAyahsFor(tester, 'الفاتحة');

      await tester.enterText(toField(), '8');
      await tester.tap(find.text('حفظ'));
      await tester.tap(find.text('تسجيل'));
      await tester.pumpAndSettle();

      expect(find.textContaining('بين 1 و 7'), findsOneWidget);
      expect(sent, isEmpty);

      // Typing again clears the message.
      await tester.enterText(toField(), '7');
      await tester.pumpAndSettle();
      expect(find.textContaining('بين 1 و 7'), findsNothing);
    });

    testWidgets('pulls the range inside a shorter surah', (tester) async {
      _setPhoneViewport(tester);
      await openAyahsFor(tester, 'البقرة');
      await tester.enterText(fromField(), '5');
      await tester.enterText(toField(), '200');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الفاتحة').last);
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('continues from the ayah after last session', (tester) async {
      _setPhoneViewport(tester);
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode([
          {
            'subject': 'QURAN',
            'unit': 'AYAH',
            'surahNumber': 2,
            'ayahFrom': 1,
            'ayahTo': 10,
            'memorizationType': 'MEMORIZING',
            'amountDone': 10,
            'date': '2026-10-20',
          },
        ]),
      );
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();

      expect(find.text('البقرة'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });
  });

  // The surah is optional: a teacher may record only how much was recited.
  group('without a surah', () {
    List<Map<String, dynamic>> captureSent() {
      final sent = <Map<String, dynamic>>[];
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode({'id': 5}),
        onRequest: (options) {
          if (options.method == 'POST') {
            sent.add(Map<String, dynamic>.from(options.data as Map));
          }
        },
      );
      return sent;
    }

    testWidgets('saves pages with no surah attached', (tester) async {
      _setPhoneViewport(tester);
      final sent = captureSent();
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.text('حفظ'));
      await tester.tap(find.text('تسجيل'));
      await tester.pumpAndSettle();

      expect(sent.single.containsKey('surahNumber'), isFalse);
      expect(sent.single.containsKey('unit'), isFalse);
      expect(sent.single['amountDone'], 2);
    });

    testWidgets('counts ayahs as a whole number, with no range', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      final sent = captureSent();
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('آيات'));
      await tester.pumpAndSettle();
      expect(find.text('عدد الآيات'), findsOneWidget);
      expect(find.text('من آية'), findsNothing);

      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('حفظ'));
      await tester.tap(find.text('تسجيل'));
      await tester.pumpAndSettle();

      expect(sent.single['unit'], 'AYAH');
      expect(sent.single['amountDone'], 12);
      expect(sent.single.containsKey('surahNumber'), isFalse);
      expect(sent.single.containsKey('ayahFrom'), isFalse);
      expect(sent.single.containsKey('ayahTo'), isFalse);
    });

    testWidgets('clearing the surah keeps the typed range as a count', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('آيات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بدون تحديد السورة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('البقرة').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '1');
      await tester.enterText(find.byType(TextField).at(0), '20');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      // The menu opens scrolled to the picked surah, so the first choice may
      // sit above the fold.
      await tester.ensureVisible(find.text('بدون تحديد السورة').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('بدون تحديد السورة').last);
      await tester.pumpAndSettle();

      expect(find.text('من آية'), findsNothing);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets("carries on from last session's ayah count", (tester) async {
      _setPhoneViewport(tester);
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode([
          {
            'subject': 'QURAN',
            'unit': 'AYAH',
            'surahNumber': null,
            'memorizationType': 'MEMORIZING',
            'amountDone': 15,
            'date': '2026-10-20',
          },
        ]),
      );
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();

      expect(find.text('عدد الآيات'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.textContaining('القرآن الكريم'), findsOneWidget);
    });
  });

  group('prefill from the last Quran entry', () {
    void stubHistory() {
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode([
          {
            'subject': 'QURAN',
            'surahNumber': 3,
            'memorizationType': 'SMALLREVISION',
            'amountDone': 4,
            'date': '2026-10-01',
          },
          {
            'subject': 'QURAN',
            'surahNumber': 2,
            'memorizationType': 'MEMORIZING',
            'amountDone': 2.5,
            'date': '2026-10-20',
          },
        ]),
      );
    }

    testWidgets('opens on the latest surah, type and pages', (tester) async {
      _setPhoneViewport(tester);
      stubHistory();
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();

      expect(find.text('بدون تحديد السورة'), findsNothing);
      expect(find.text('البقرة'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);
      // Named above the form, so the choices read as last session's.
      expect(find.textContaining('آخر تسجيل'), findsOneWidget);
    });

    testWidgets('leaves the form empty for a student with no history', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      await tester.pumpWidget(
        _host(MemorizationEntrySheet(student: _student())),
      );
      await tester.pumpAndSettle();

      expect(find.text('بدون تحديد السورة'), findsOneWidget);
      expect(find.textContaining('آخر تسجيل'), findsNothing);
    });
  });

  testWidgets('offers to move on only when there is a next student', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(
        MemorizationEntrySheet(student: _student(), nextStudentName: 'أحمد'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('التالي: أحمد'), findsOneWidget);
    expect(find.text('تسجيل والتالي'), findsOneWidget);
    expect(find.text('تسجيل والعودة'), findsOneWidget);
    expect(find.text('تسجيل'), findsNothing);
  });

  testWidgets('a long next name does not overflow the sheet', (tester) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _host(
        MemorizationEntrySheet(
          student: _student(),
          nextStudentName: 'عبد الرحمن بن عبد العزيز بن محمد آل عبد اللطيف',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('outside the session', () {
    final students = [
      const TeacherStudentModel(
        id: 1,
        fullName: 'محمد بن صالح',
        isActive: true,
      ),
      const TeacherStudentModel(id: 2, fullName: 'عمر الفاروق', isActive: true),
    ];

    List<Map<String, dynamic>> captureSent() {
      final sent = <Map<String, dynamic>>[];
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode({'id': 5}),
        onRequest: (options) {
          if (options.method == 'POST') {
            sent.add(Map<String, dynamic>.from(options.data as Map));
          }
        },
      );
      return sent;
    }

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        _host(MemorizationEntrySheet.outsideSession(students: students)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the student before showing the form', (tester) async {
      _setPhoneViewport(tester);
      await open(tester);

      expect(find.text('تسجيل حفظ خارج الحصة'), findsOneWidget);
      expect(find.text('اختر الطالب'), findsOneWidget);
      expect(find.text('بدون تحديد السورة'), findsNothing);
      expect(find.text('تسجيل'), findsNothing);
    });

    testWidgets('finds a student by searching their name', (tester) async {
      _setPhoneViewport(tester);
      await open(tester);

      await tester.tap(find.text('اختر الطالب'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'عمر');
      await tester.pumpAndSettle();

      expect(find.text('عمر الفاروق'), findsOneWidget);
      expect(find.text('محمد بن صالح'), findsNothing);

      await tester.tap(find.text('عمر الفاروق'));
      await tester.pumpAndSettle();
      expect(find.text('بدون تحديد السورة'), findsOneWidget);
    });

    testWidgets('saves the entry as outside the session', (tester) async {
      _setPhoneViewport(tester);
      final sent = captureSent();
      await open(tester);

      await tester.tap(find.text('اختر الطالب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عمر الفاروق'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بدون تحديد السورة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الفاتحة').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.tap(find.text('تسجيل'));
      await tester.pumpAndSettle();

      expect(sent.single['studentId'], 2);
      expect(sent.single['outsideSession'], true);
    });
  });

  testWidgets('a halaqa entry does not claim to be outside the session', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final sent = <Map<String, dynamic>>[];
    DioClient.instance.httpClientAdapter = _StubAdapter(
      jsonEncode({'id': 5}),
      onRequest: (options) {
        if (options.method == 'POST') {
          sent.add(Map<String, dynamic>.from(options.data as Map));
        }
      },
    );
    await tester.pumpWidget(_host(MemorizationEntrySheet(student: _student())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفاتحة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.tap(find.text('تسجيل'));
    await tester.pumpAndSettle();

    expect(sent.single.containsKey('outsideSession'), isFalse);
  });

  group('group entry', () {
    final students = [
      TeacherStudentModel(id: 1, fullName: 'محمد بن صالح', isActive: true),
      TeacherStudentModel(id: 2, fullName: 'عمر الفاروق', isActive: true),
      // Tracks hadith, yet a group entry is Quran only.
      TeacherStudentModel(
        id: 3,
        fullName: 'يوسف أمين',
        isActive: true,
        hadithBooks: kHadithBooks,
      ),
    ];

    /// Captures what the sheet posts, answering with the server's group shape:
    /// student 2 skipped as absent, everyone else written.
    List<Map<String, dynamic>> captureSent() {
      final sent = <Map<String, dynamic>>[];
      DioClient.instance.httpClientAdapter = _StubAdapter(
        jsonEncode({
          'created': [
            {'id': 50, 'studentId': 1, 'amountDone': 3},
            {'id': 51, 'studentId': 3, 'amountDone': 3},
          ],
          'skipped': [
            {'studentId': 2, 'reason': 'STUDENT_ABSENT'},
          ],
        }),
        onRequest: (options) {
          if (options.method == 'POST') {
            sent.add(Map<String, dynamic>.from(options.data as Map));
          }
        },
      );
      return sent;
    }

    /// Opens the sheet from a button, as the attendance page does, so the
    /// result it pops can be checked.
    Future<GroupMemorizationResult? Function()> open(
      WidgetTester tester, {
      Set<int> selected = const {1, 2, 3},
      Set<int> recordedToday = const {},
    }) async {
      GroupMemorizationResult? result;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result =
                        await showModalBottomSheet<GroupMemorizationResult>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => MemorizationEntrySheet.group(
                            students: students,
                            groupSelected: selected,
                            groupRecordedToday: recordedToday,
                          ),
                        );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('starts with the given students ticked', (tester) async {
      _setPhoneViewport(tester);
      await open(tester, selected: {1, 3}, recordedToday: {2});

      expect(find.text('تسجيل عرض موحّد'), findsOneWidget);
      expect(find.text('الطلاب المحددون: 2 من 3'), findsOneWidget);
      expect(find.text('مسجّل اليوم'), findsOneWidget);
      expect(find.text('تسجيل لـ 2 طالب'), findsOneWidget);
      final ticks = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value)
          .toList();
      expect(ticks, [true, false, true]);
    });

    testWidgets('offers no hadith switch, even for a hadith student', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      await open(tester);

      expect(find.text('الحديث'), findsNothing);
      expect(find.text('السورة (اختياري)'), findsOneWidget);
    });

    testWidgets('a tap on the row toggles the student', (tester) async {
      _setPhoneViewport(tester);
      await open(tester);

      await tester.tap(find.text('عمر الفاروق'));
      await tester.pumpAndSettle();

      expect(find.text('الطلاب المحددون: 2 من 3'), findsOneWidget);
    });

    testWidgets('select all ticks everyone, and again clears them', (
      tester,
    ) async {
      _setPhoneViewport(tester);
      await open(tester, selected: {1});

      await tester.tap(find.text('تحديد الكل'));
      await tester.pumpAndSettle();
      expect(find.text('الطلاب المحددون: 3 من 3'), findsOneWidget);

      await tester.tap(find.text('إلغاء تحديد الكل'));
      await tester.pumpAndSettle();
      expect(find.text('الطلاب المحددون: 0 من 3'), findsOneWidget);
    });

    testWidgets('cannot save with nobody ticked', (tester) async {
      _setPhoneViewport(tester);
      final sent = captureSent();
      await open(tester, selected: {});

      final save = find.ancestor(
        of: find.text('اختر الطلاب أولاً'),
        matching: find.byType(AppButton),
      );
      expect(tester.widget<AppButton>(save).onPressed, isNull);
      expect(sent, isEmpty);
    });

    testWidgets('sends one entry for the ticked students and hands back '
        'who was written and who was skipped', (tester) async {
      _setPhoneViewport(tester);
      final sent = captureSent();
      final result = await open(tester);

      await tester.tap(find.text('آيات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بدون تحديد السورة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الفاتحة').last);
      await tester.pumpAndSettle();
      // Row order is left to right: «إلى آية» first, «من آية» on the right.
      await tester.enterText(find.byType(TextField).at(1), '1');
      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.tap(find.text('حفظ'));
      // The student list makes this sheet taller than the screen.
      await tester.ensureVisible(find.text('تسجيل لـ 3 طالب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل لـ 3 طالب'));
      await tester.pumpAndSettle();

      expect(sent.single['studentIds'], [1, 2, 3]);
      expect(sent.single['entry'], {
        'surahNumber': 1,
        'amountDone': 3,
        'memorizationType': 'MEMORIZING',
        'unit': 'AYAH',
        'ayahFrom': 1,
        'ayahTo': 3,
      });
      expect(result()!.created.map((r) => r['studentId']), [1, 3]);
      expect(result()!.skippedAbsent, [2]);
    });
  });
}
