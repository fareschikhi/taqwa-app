import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/confirm_discard_memorization_dialog.dart';

/// Pumps a button that opens the dialog and records what `show` resolved to,
/// so the tests exercise the real static entry point the page calls rather
/// than constructing the widget directly.
Future<void> _openDialog(
  WidgetTester tester, {
  required void Function(bool) onResult,
  String studentName = 'محمد بن صالح',
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await ConfirmDiscardMemorizationDialog.show(
                  context,
                  studentName: studentName,
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
  testWidgets('names the student whose memorization would be discarded', (
    tester,
  ) async {
    await _openDialog(tester, onResult: (_) {}, studentName: 'يوسف طارق');

    expect(
      find.textContaining('يوسف طارق'),
      findsOneWidget,
      reason:
          'the teacher taps this from a long list, so the dialog has to '
          'say which student it is about',
    );
  });

  testWidgets('warns that the record is deleted permanently', (tester) async {
    await _openDialog(tester, onResult: (_) {});

    expect(find.text('حذف تسميع اليوم؟'), findsOneWidget);
    expect(find.textContaining('نهائياً'), findsOneWidget);
  });

  testWidgets('resolves true when the teacher confirms', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tap(find.text('تحديد كغائب'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('resolves false when the teacher cancels', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('treats a dismissal as declining', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    // Tapping the barrier outside the dialog pops with null.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(
      result,
      isFalse,
      reason: 'dismissing must never be read as consent to delete',
    );
  });
}
