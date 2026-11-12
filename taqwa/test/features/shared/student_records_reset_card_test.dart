import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/shared/presentation/widgets/student_records_reset_card.dart';

import '../../helpers/stub_api.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentRecordsResetCard(studentId: 7),
          ),
        ),
      ),
    ),
  );
  // Lets the summary request answer; no animation is running yet.
  await tester.pumpAndSettle();
}

final _inCard = find.byType(StudentRecordsResetCard);
Finder _cardText(String text) =>
    find.descendant(of: _inCard, matching: find.text(text));

/// Past the undo window, and long enough for the DELETE to answer.
Future<void> _waitOutWindow(WidgetTester tester) async {
  await tester.pump(StudentRecordsResetCard.undoWindow);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  late StubApi api;
  setUp(() {
    api = StubApi.install((r) {
      if (r.method == 'GET' && r.path.endsWith('/students/7/records')) {
        return (
          200,
          {
            'attendance': 12,
            'memorization': 0,
            'points': 3,
            'pointsTotal': 7.25,
          },
        );
      }
      if (r.method == 'DELETE') return (200, {'deleted': 1});
      return (404, {'message': 'unexpected ${r.method} ${r.path}'});
    });
  });

  testWidgets('shows what each reset would erase', (tester) async {
    await _pump(tester);

    expect(_cardText('عدد السجلات: 12'), findsOneWidget);
    expect(_cardText('الرصيد: 7.25 · عدد القيود: 3'), findsOneWidget);
    // Memorization has nothing to clear, so its button is off.
    expect(_cardText('لا توجد سجلات'), findsOneWidget);
    final memo = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('مسح الحفظ'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(memo.onPressed, isNull);
  });

  testWidgets('deletes only once the undo window has passed', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('مسح الحضور'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(api.sent('DELETE', '/students/7'), isEmpty);

    await _waitOutWindow(tester);
    expect(api.sent('DELETE', '/students/7/attendance'), hasLength(1));
    expect(api.sent('DELETE', '/students/7/points'), isEmpty);
    expect(_cardText('لا توجد سجلات'), findsNWidgets(2));
  });

  testWidgets('the inline undo cancels the deletion', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('مسح النقاط'));
    await tester.pump();
    await tester.tap(_cardText('تراجع'));
    await tester.pump();

    await _waitOutWindow(tester);
    expect(api.sent('DELETE', '/students/7'), isEmpty);
    expect(_cardText('مسح النقاط'), findsOneWidget);
  });

  testWidgets('the snackbar undo cancels the deletion', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('مسح الحضور'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750)); // snackbar slides in
    await tester.tap(
      find.descendant(of: find.byType(SnackBar), matching: find.text('تراجع')),
    );
    await tester.pump();

    await _waitOutWindow(tester);
    expect(api.sent('DELETE', '/students/7'), isEmpty);
    expect(_cardText('عدد السجلات: 12'), findsOneWidget);
  });
}
