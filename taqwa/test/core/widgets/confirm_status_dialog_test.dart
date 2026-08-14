import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/confirm_status_dialog.dart';

/// Pumps a button that opens the dialog and records what `show` resolved to,
/// so the tests exercise the real static entry point the pages call rather
/// than constructing the widget directly.
Future<void> _openDialog(
  WidgetTester tester, {
  required bool isCurrentlyActive,
  required void Function(bool) onResult,
  String userName = 'محمد بن صالح',
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await ConfirmStatusDialog.show(
                  context,
                  isCurrentlyActive: isCurrentlyActive,
                  userName: userName,
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
  testWidgets('deactivating warns with the blocking icon and label', (
    tester,
  ) async {
    await _openDialog(
      tester,
      isCurrentlyActive: true,
      onResult: (_) {},
    );

    expect(find.text('تعطيل الحساب؟'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.text('تعطيل'), findsOneWidget);
    expect(find.text('تفعيل'), findsNothing);
  });

  testWidgets('activating offers the opposite icon and label', (tester) async {
    await _openDialog(
      tester,
      isCurrentlyActive: false,
      onResult: (_) {},
    );

    expect(find.text('تفعيل الحساب؟'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('تفعيل'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsNothing);
  });

  // The admin is about to lock a specific person out; the prompt has to say
  // which one, not just "this account".
  testWidgets('names the user being changed', (tester) async {
    await _openDialog(
      tester,
      isCurrentlyActive: true,
      userName: 'فاطمة الزهراء',
      onResult: (_) {},
    );

    expect(
      find.textContaining('فاطمة الزهراء'),
      findsOneWidget,
      reason: 'the message must identify who is affected',
    );
  });

  testWidgets('confirming resolves true', (tester) async {
    bool? result;
    await _openDialog(
      tester,
      isCurrentlyActive: true,
      onResult: (r) => result = r,
    );

    await tester.tap(find.text('تعطيل'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('cancelling resolves false', (tester) async {
    bool? result;
    await _openDialog(
      tester,
      isCurrentlyActive: true,
      onResult: (r) => result = r,
    );

    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  // Dismissing by tapping outside pops with null; `show` must not leak that
  // to callers as a confirmation.
  testWidgets('dismissing without choosing resolves false', (tester) async {
    bool? result;
    await _openDialog(
      tester,
      isCurrentlyActive: true,
      onResult: (r) => result = r,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
