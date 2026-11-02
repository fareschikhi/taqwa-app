import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/attendance_controls.dart';

/// The selector as the student tile builds it: full width inside a list,
/// which is the constraint environment that matters — a `Center` hands down
/// a finite height the real `ListView` never does.
Future<List<AttendanceStatus>> _pump(
  WidgetTester tester, {
  AttendanceStatus status = AttendanceStatus.present,
  String? lateFeeLabel = '1000 دج',
  bool enabled = true,
}) async {
  final picked = <AttendanceStatus>[];
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              AttendanceSelector(
                status: status,
                lateFeeLabel: lateFeeLabel,
                enabled: enabled,
                onChanged: picked.add,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return picked;
}

void main() {
  testWidgets('renders all three marks inside an unbounded list', (
    tester,
  ) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('حاضر'), findsOneWidget);
    expect(find.text('متأخر'), findsOneWidget);
    expect(find.text('غائب'), findsOneWidget);
  });

  // The whole point of the selector: no menu to open first.
  testWidgets('reports a mark from a single tap', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.text('غائب'));
    await tester.pump();

    expect(picked, [AttendanceStatus.absent]);
  });

  testWidgets('tapping the mark already chosen reports nothing', (
    tester,
  ) async {
    final picked = await _pump(tester);
    await tester.tap(find.text('حاضر'));
    await tester.pump();

    expect(picked, isEmpty);
  });

  // The app is laid out left to right, so the first mark an Arabic reader
  // meets has to be the rightmost one.
  testWidgets('puts present on the right', (tester) async {
    await _pump(tester);

    final present = tester.getCenter(find.text('حاضر')).dx;
    final late = tester.getCenter(find.text('متأخر')).dx;
    final absent = tester.getCenter(find.text('غائب')).dx;
    expect(present, greaterThan(late));
    expect(late, greaterThan(absent));
  });

  group('late fee', () {
    testWidgets('is readable before late is chosen', (tester) async {
      await _pump(tester);

      expect(find.text('1000 دج'), findsOneWidget);
    });

    testWidgets('is left off when lateness is free', (tester) async {
      await _pump(tester, lateFeeLabel: null);

      expect(find.textContaining('دج'), findsNothing);
    });
  });

  testWidgets('a disabled selector ignores taps', (tester) async {
    final picked = await _pump(tester, enabled: false);
    await tester.tap(find.text('غائب'));
    await tester.pump();

    expect(picked, isEmpty);
  });
}
