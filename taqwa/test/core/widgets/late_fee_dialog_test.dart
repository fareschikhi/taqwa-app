import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/late_fee_dialog.dart';

/// Opens the dialog from a button and records what it returned.
Future<List<int?>> _open(WidgetTester tester, {int defaultFee = 10}) async {
  final results = <int?>[];
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await LateFeeDialog.show(
                  context,
                  title: 'طالب',
                  defaultFee: defaultFee,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('lateFeeError', () {
    test('accepts zero and ordinary amounts', () {
      expect(lateFeeError('0'), isNull);
      expect(lateFeeError(' 15 '), isNull);
    });

    test('refuses blank, non-numbers and amounts over the ceiling', () {
      expect(lateFeeError(''), isNotNull);
      expect(lateFeeError('abc'), isNotNull);
      expect(lateFeeError('${maxLateFee + 1}'), isNotNull);
    });
  });

  testWidgets('starts on the halaqa rate and returns it on confirm', (
    tester,
  ) async {
    final results = await _open(tester, defaultFee: 10);

    expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    await tester.tap(find.text('تسجيل التأخر'));
    await tester.pumpAndSettle();

    expect(results, [10]);
  });

  testWidgets('returns the amount the teacher typed', (tester) async {
    final results = await _open(tester);

    await tester.enterText(find.byType(TextField), '35');
    await tester.tap(find.text('تسجيل التأخر'));
    await tester.pumpAndSettle();

    expect(results, [35]);
  });

  testWidgets('the waive chip returns 0', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text('بدون غرامة'));
    await tester.pump();
    await tester.tap(find.text('تسجيل التأخر'));
    await tester.pumpAndSettle();

    expect(results, [0]);
  });

  testWidgets('cancel returns null so the mark does not change', (
    tester,
  ) async {
    final results = await _open(tester);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('a blank amount shows an error and keeps the dialog open', (
    tester,
  ) async {
    final results = await _open(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('تسجيل التأخر'));
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(find.text('أدخل مبلغاً صحيحاً'), findsOneWidget);
  });
}
