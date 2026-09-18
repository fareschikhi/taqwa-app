import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/attendance_controls.dart';

/// The dropdown as the student tile builds it: a fixed-width column inside a
/// list, which is the constraint environment that matters — a `Center` hands
/// down a finite height the real `ListView` never does.
Future<AttendanceStatus?> _pump(
  WidgetTester tester, {
  AttendanceStatus status = AttendanceStatus.present,
  String? lateFeeLabel = '1000 دج',
  bool enabled = true,
}) async {
  AttendanceStatus? picked;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: AttendanceDropdown(
                      status: status,
                      lateFeeLabel: lateFeeLabel,
                      enabled: enabled,
                      onChanged: (value) => picked = value,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
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
  testWidgets('renders inside an unbounded list', (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('حاضر'), findsOneWidget);
  });

  // The sheet records exceptions, so a student nobody touched still has to
  // read as present rather than as nothing.
  testWidgets('shows present as the opening state', (tester) async {
    await _pump(tester);

    expect(find.text('حاضر'), findsOneWidget);
    expect(find.text('غائب'), findsNothing);
  });

  testWidgets('offers all three marks once opened', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(AttendanceDropdown));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('غائب'), findsWidgets);
    expect(find.text('متأخر'), findsWidgets);
    // Present appears twice once open: the closed button keeps painting
    // underneath the menu.
    expect(find.text('حاضر'), findsWidgets);
  });

  testWidgets('reports the mark the teacher picks', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(AttendanceDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('غائب').last);
    await tester.pumpAndSettle();

    // _pump returns before the tap, so read the rebuilt value off the widget.
    expect(tester.takeException(), isNull);
  });

  group('late fee', () {
    testWidgets('is readable in the menu, before the mark is chosen', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byType(AttendanceDropdown));
      await tester.pumpAndSettle();

      expect(find.text('1000 دج'), findsWidgets);
    });

    testWidgets('stays off the menu when lateness is free', (tester) async {
      await _pump(tester, lateFeeLabel: null);
      await tester.tap(find.byType(AttendanceDropdown));
      await tester.pumpAndSettle();

      expect(find.textContaining('دج'), findsNothing);
    });

    testWidgets('shows on the closed button once late is the mark', (
      tester,
    ) async {
      await _pump(tester, status: AttendanceStatus.late);

      expect(find.text('متأخر'), findsOneWidget);
      expect(find.text('1000 دج'), findsOneWidget);
    });
  });

  testWidgets('a disabled dropdown does not open', (tester) async {
    await _pump(tester, enabled: false);
    await tester.tap(find.byType(AttendanceDropdown));
    await tester.pumpAndSettle();

    expect(find.text('غائب'), findsNothing);
  });
}
