import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/record_delete_button.dart';
import 'package:taqwa/features/parent/presentation/pages/child_attendance_history_page.dart';
import 'package:taqwa/features/parent/presentation/pages/child_progress_page.dart';
import 'package:taqwa/features/parent/presentation/widgets/parent_chat_button.dart';
import 'package:taqwa/features/shared/presentation/pages/student_details_page.dart';

import '../../helpers/stub_api.dart';

Widget _host(Widget child) => ProviderScope(
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(home: child),
  ),
);

/// Phone-sized surface. The test font draws every glyph as a full square, so
/// Arabic headings can overflow rows that fit on a phone. These tests check
/// content, not layout, so RenderFlex overflow reports are dropped.
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

/// Twelve recitations on 1–12 October: two more than the profile's last-ten
/// list holds, so the oldest day (01/10) only shows on the full history.
final _records = [
  for (var d = 1; d <= 12; d++)
    {
      'id': d,
      'subject': 'QURAN',
      'surahNumber': d,
      'memorizationType': 'MEMORIZING',
      'amountDone': 1,
      'unit': 'PAGE',
      'date': '2026-10-${d.toString().padLeft(2, '0')}',
      'recordedAt': '2026-10-${d.toString().padLeft(2, '0')}T10:00:00.000Z',
    },
];

StubApi _installApi() => StubApi.install((request) {
  final path = request.path;
  if (request.method == 'DELETE') return (200, {'deleted': true});
  if (path.endsWith('/students/7/profile')) {
    return (
      200,
      {
        'id': 7,
        'user': {'fullName': 'أحمد', 'role': 'STUDENT'},
        // The profile carries only the newest ten.
        'memorization': _records.reversed.take(10).toList(),
      },
    );
  }
  if (path.endsWith('/memorization/student/7/progress')) {
    return (
      200,
      {
        'totalPagesDone': 12,
        'totalAyahsDone': 0,
        'totalSurahs': 12,
        'typeCounts': {'MEMORIZING': 12},
        'hadithTypeCounts': <String, dynamic>{},
      },
    );
  }
  if (path.endsWith('/memorization/student/7')) return (200, _records);
  if (path.endsWith('/attendance/student/7/summary')) {
    return (200, {'month': 11, 'monthPresent': 2, 'monthAbsent': 1});
  }
  if (path.endsWith('/attendance/student/7')) {
    return (
      200,
      [
        {'id': 21, 'date': '2026-11-10', 'status': 'PRESENT'},
        {'id': 22, 'date': '2026-11-09', 'status': 'ABSENT'},
      ],
    );
  }
  return (404, {'message': 'not stubbed'});
});

void main() {
  testWidgets('عرض الكل opens every recitation, not just the last ten', (
    tester,
  ) async {
    _phoneScreen(tester);
    _installApi();
    await tester.pumpWidget(
      _host(const StudentDetailsPage(studentId: 7, fullName: 'أحمد')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('عرض الكل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض الكل'));
    await tester.pumpAndSettle();

    final page = find.byType(ChildProgressPage);
    expect(page, findsOneWidget);
    // Opened for one student: a back button, not the parent's chat shortcut.
    expect(find.byType(ParentChatButton), findsNothing);
    expect(find.byTooltip('رجوع'), findsOneWidget);
    // Nothing is trimmed, so the "last N" label stays off.
    expect(find.text('آخر 10 إدخالات'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('01/10'),
      300,
      scrollable: find
          .descendant(of: page, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('01/10'), findsOneWidget);
  });

  testWidgets('the attendance box opens the attendance timeline', (
    tester,
  ) async {
    _phoneScreen(tester);
    final api = _installApi();
    await tester.pumpWidget(
      _host(const StudentDetailsPage(studentId: 7, fullName: 'أحمد')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('أيام الحضور هذا الشهر'));
    await tester.pumpAndSettle();

    expect(find.byType(ChildAttendanceHistoryPage), findsOneWidget);
    expect(find.byType(ParentChatButton), findsNothing);
    expect(find.text('سجلات حضور أحمد وغيابه.'), findsOneWidget);
    expect(
      api.requests.where((r) => r.path.endsWith('/attendance/student/7')),
      isNotEmpty,
    );

    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.byType(ChildAttendanceHistoryPage), findsNothing);
    expect(find.text('ملف الطالب'), findsOneWidget);
  });

  testWidgets('a read-only visitor gets no delete buttons', (tester) async {
    _phoneScreen(tester);
    _installApi();
    await tester.pumpWidget(
      _host(const StudentDetailsPage(studentId: 7, fullName: 'أحمد')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('أيام الحضور هذا الشهر'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordDeleteButton), findsNothing);
  });

  testWidgets('staff delete a recitation after confirming, then the profile '
      'reloads', (tester) async {
    _phoneScreen(tester);
    final api = _installApi();
    await tester.pumpWidget(
      _host(
        const StudentDetailsPage(
          studentId: 7,
          fullName: 'أحمد',
          canDeleteRecords: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('عرض الكل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض الكل'));
    await tester.pumpAndSettle();

    // The oldest entry, 1 October, is the record with id 1.
    final button = find.byWidgetPredicate(
      (w) => w is RecordDeleteButton && w.tooltip.contains('01/10'),
    );
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ChildProgressPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    // Nothing is sent until the dialog is confirmed.
    expect(find.text('حذف التسميع'), findsOneWidget);
    expect(api.sent('DELETE', '/memorization/'), isEmpty);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(api.sent('DELETE', '/memorization/1'), hasLength(1));
    expect(find.text('تم حذف التسميع'), findsOneWidget);

    // The header button has scrolled away; leave with the system back, as
    // most phones do.
    final profileReads = api.sent('GET', '/students/7/profile').length;
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(api.sent('GET', '/students/7/profile').length, profileReads + 1);
  });

  testWidgets('cancelling the dialog keeps the attendance day', (tester) async {
    _phoneScreen(tester);
    final api = _installApi();
    await tester.pumpWidget(
      _host(
        const StudentDetailsPage(
          studentId: 7,
          fullName: 'أحمد',
          canDeleteRecords: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('أيام الحضور هذا الشهر'));
    await tester.pumpAndSettle();

    final button = find.byWidgetPredicate(
      (w) => w is RecordDeleteButton && w.tooltip.contains('09/11/2026'),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();
    expect(api.sent('DELETE', '/attendance/'), isEmpty);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(api.sent('DELETE', '/attendance/22'), hasLength(1));
    expect(find.text('تم حذف سجل الحضور'), findsOneWidget);
  });
}
