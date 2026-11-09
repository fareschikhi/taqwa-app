import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/student_of_month_card.dart';
import 'package:taqwa/features/data/models/student_of_month_model.dart';

const _pick = StudentOfMonthModel(
  halaqaId: 5,
  halaqaName: 'حلقة النور',
  month: '2026-11',
  studentId: 2,
  fullName: 'بلال بن رباح',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}

void main() {
  test('month keys read as Algerian month names', () {
    expect(monthLabel('2026-11'), 'نوفمبر 2026');
    expect(monthLabel('2027-01'), 'جانفي 2027');
    expect(monthLabel('bad'), 'bad');
  });

  testWidgets('introduces the winner to classmates', (tester) async {
    await _pump(tester, const StudentOfMonthCard(pick: _pick));
    expect(find.text('طالب شهر نوفمبر 2026'), findsOneWidget);
    expect(find.text('بلال بن رباح'), findsOneWidget);
    expect(find.text('حلقة النور'), findsOneWidget);
    expect(find.textContaining('قدوة لزملائه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('congratulates the winner himself', (tester) async {
    await _pump(tester, const StudentOfMonthCard(pick: _pick, isViewer: true));
    expect(find.textContaining('اجتهادك'), findsOneWidget);
  });

  testWidgets("congratulates the winner's parent", (tester) async {
    await _pump(
      tester,
      const StudentOfMonthCard(
        pick: _pick,
        isViewer: true,
        viewerIsParent: true,
      ),
    );
    expect(find.textContaining('ابنكم'), findsOneWidget);
  });

  testWidgets('a long name does not overflow a phone-width card', (
    tester,
  ) async {
    await _pump(
      tester,
      const StudentOfMonthCard(
        pick: StudentOfMonthModel(
          halaqaId: 5,
          halaqaName: 'حلقة الإمام نافع لتحفيظ القرآن الكريم للكبار',
          month: '2026-11',
          studentId: 2,
          fullName: 'عبد الرحمن بن عبد الله بن محمد بن إبراهيم الجزائري',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
