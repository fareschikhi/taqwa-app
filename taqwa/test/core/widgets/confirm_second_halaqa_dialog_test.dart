import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/confirm_second_halaqa_dialog.dart';

/// Pumps a button that opens the dialog and records what `show` resolved to,
/// so the tests exercise the real static entry point the page calls rather
/// than constructing the widget directly.
Future<void> _openDialog(
  WidgetTester tester, {
  required void Function(bool) onResult,
  String teacherName = 'محمد بن صالح',
  List<String> existingHalaqas = const ['حلقة الفجر'],
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await ConfirmSecondHalaqaDialog.show(
                  context,
                  teacherName: teacherName,
                  existingHalaqas: existingHalaqas,
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
  testWidgets('asks about a second halaqa in warning colours', (tester) async {
    await _openDialog(tester, onResult: (_) {});

    expect(find.text('إسناد حلقة ثانية؟'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  // The admin is picking from a list of names; the prompt has to say which
  // teacher it is talking about.
  testWidgets('names the teacher taking the extra halaqa', (tester) async {
    await _openDialog(tester, teacherName: 'فاطمة الزهراء', onResult: (_) {});

    expect(
      find.textContaining('فاطمة الزهراء'),
      findsOneWidget,
      reason: 'the message must identify whose load is growing',
    );
  });

  // A bare count would leave the admin to go and look them up. Naming them is
  // what lets her tell a deliberate second halaqa from a misclick.
  testWidgets('names every halaqa she already runs', (tester) async {
    await _openDialog(
      tester,
      existingHalaqas: const ['حلقة الفجر', 'حلقة النور'],
      onResult: (_) {},
    );

    expect(find.textContaining('حلقة الفجر'), findsOneWidget);
    expect(find.textContaining('حلقة النور'), findsOneWidget);
  });

  testWidgets('states the one-halaqa norm being departed from', (tester) async {
    await _openDialog(tester, onResult: (_) {});

    expect(find.textContaining('حلقة واحدة'), findsOneWidget);
  });

  testWidgets('confirming resolves true', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tap(find.text('إسناد'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('cancelling resolves false', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  // Dismissing by tapping outside pops with null; `show` must not leak that
  // to callers as a confirmation.
  testWidgets('dismissing without choosing resolves false', (tester) async {
    bool? result;
    await _openDialog(tester, onResult: (r) => result = r);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
