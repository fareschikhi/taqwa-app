import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/parent/presentation/pages/child_progress_page.dart';
import 'package:taqwa/features/shared/presentation/pages/student_details_page.dart';

import '../../helpers/stub_api.dart';

Widget _host(Widget child) => ProviderScope(
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(home: child),
  ),
);

/// Same phone surface as the other history tests: overflow reports from the
/// square test glyphs are dropped, anything else still fails.
void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

/// One plain Quran entry and one تسميع with the teacher's mistakes.
final _records = [
  {
    'id': 1,
    'subject': 'QURAN',
    'surahNumber': 2,
    'memorizationType': 'MEMORIZING',
    'amountDone': 1,
    'unit': 'PAGE',
    'date': '2026-11-10',
    'recordedAt': '2026-11-10T10:00:00.000Z',
  },
  {
    'id': 2,
    'subject': 'TASMEE',
    'surahNumber': 18,
    'memorizationType': 'BIGREVISION',
    'amountDone': 3,
    'unit': 'PAGE',
    'mistakes': 'تردد في الآية 5',
    'date': '2026-11-12',
    'recordedAt': '2026-11-12T10:00:00.000Z',
  },
];

void _installApi() => StubApi.install((request) {
  final path = request.path;
  if (path.endsWith('/students/7/profile')) {
    return (
      200,
      {
        'id': 7,
        'user': {'fullName': 'أحمد', 'role': 'STUDENT'},
        'memorization': _records.reversed.toList(),
      },
    );
  }
  if (path.endsWith('/memorization/student/7/progress')) {
    return (
      200,
      {
        'records': _records.reversed.toList(),
        'totalPagesDone': 1,
        'totalAyahsDone': 0,
        'totalSurahs': 1,
        'typeCounts': {'MEMORIZING': 1},
        'hadithTypeCounts': <String, dynamic>{},
        'tracksTasmee': true,
      },
    );
  }
  if (path.endsWith('/memorization/student/7')) return (200, _records);
  if (path.endsWith('/attendance/student/7/summary')) {
    return (200, {'month': 11, 'monthPresent': 0, 'monthAbsent': 0});
  }
  if (path.endsWith('/attendance/student/7')) return (200, <dynamic>[]);
  return (404, {'message': 'not stubbed'});
});

void main() {
  testWidgets('the profile labels a تسميع and shows its mistakes', (
    tester,
  ) async {
    _phoneScreen(tester);
    _installApi();
    await tester.pumpWidget(
      _host(const StudentDetailsPage(studentId: 7, fullName: 'أحمد')),
    );
    await tester.pumpAndSettle();

    final mistakes = find.text('الأخطاء: تردد في الآية 5');
    await tester.scrollUntilVisible(
      mistakes,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(mistakes, findsOneWidget);
    expect(find.text('تسميع · مراجعة وضبط'), findsWidgets);
    // The Quran entry has no mistakes line.
    expect(find.textContaining('الأخطاء:'), findsOneWidget);
  });

  testWidgets('the full history labels a تسميع and shows its mistakes', (
    tester,
  ) async {
    _phoneScreen(tester);
    _installApi();
    await tester.pumpWidget(
      _host(const ChildProgressPage(studentId: 7, studentName: 'أحمد')),
    );
    await tester.pumpAndSettle();

    final mistakes = find.text('الأخطاء: تردد في الآية 5');
    await tester.scrollUntilVisible(
      mistakes,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(mistakes, findsOneWidget);
    expect(find.text('تسميع · مراجعة وضبط'), findsWidgets);
  });
}
