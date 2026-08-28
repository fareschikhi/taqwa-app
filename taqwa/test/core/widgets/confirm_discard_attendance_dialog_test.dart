import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/confirm_discard_attendance_dialog.dart';

/// Pumps a button that opens the dialog and records what `show` resolved to,
/// so the tests exercise the real static entry point the page calls rather
/// than constructing the widget directly.
Future<void> _openDialog(
  WidgetTester tester, {
  required void Function(bool) onResult,
  int pendingCount = 3,
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await ConfirmDiscardAttendanceDialog.show(
                  context,
                  pendingCount: pendingCount,
                );
                onResult(result);
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
}

void main() {
  testWidgets('says how many students would be lost', (tester) async {
    await _openDialog(tester, pendingCount: 7, onResult: (_) {});

    expect(find.textContaining('7'), findsOneWidget);
  });

  testWidgets('discards only when the teacher chooses to', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tap(find.text('خروج بدون حفظ'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('staying keeps the attendance', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tap(find.text('البقاء'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  // Dismissing by tapping outside resolves to null, which must not be read as
  // permission to throw the attendance away.
  testWidgets('a dismissal is not a discard', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
