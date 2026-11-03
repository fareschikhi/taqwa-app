import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/app_text_field.dart';
import 'package:taqwa/core/widgets/points_adjust_dialog.dart';

typedef _Call = ({num amount, String? reason});

/// A button that opens the dialog; what it returned lands in [result].
class _Opener extends StatelessWidget {
  const _Opener({required this.onSubmit, required this.result});
  final Future<void> Function(num, String?) onSubmit;
  final ValueNotifier<bool?> result;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () async => result.value = await PointsAdjustDialog.show(
      context,
      onSubmit: onSubmit,
    ),
    child: const Text('open'),
  );
}

Future<ValueNotifier<bool?>> _open(
  WidgetTester tester,
  Future<void> Function(num, String?) onSubmit,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final result = ValueNotifier<bool?>(null);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: _Opener(onSubmit: onSubmit, result: result),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(TextField),
);

void main() {
  savingTests();
  testWidgets('subtracting sends a negative amount', (tester) async {
    final calls = <_Call>[];
    final result = await _open(
      tester,
      (amount, reason) async => calls.add((amount: amount, reason: reason)),
    );

    await tester.tap(find.text('خصم'));
    await tester.enterText(_field('العدد'), '3');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(calls, [(amount: -3, reason: null)]);
    expect(result.value, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('adding sends a positive amount and the reason', (tester) async {
    final calls = <_Call>[];
    await _open(
      tester,
      (amount, reason) async => calls.add((amount: amount, reason: reason)),
    );

    await tester.enterText(_field('العدد'), '1,5');
    await tester.enterText(_field('السبب (اختياري)'), ' سلوك ');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(calls, [(amount: 1.5, reason: 'سلوك')]);
  });

  testWidgets('a bad amount is caught before the round trip', (tester) async {
    var called = false;
    await _open(tester, (_, _) async => called = true);

    await tester.enterText(_field('العدد'), '2.255');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('رقمان بعد الفاصلة على الأكثر'), findsOneWidget);
  });

  // The server has the last word (e.g. the student left the halaqa): its
  // message shows in the dialog, which stays open with what was typed.
  testWidgets('a refusal from the server keeps the dialog open', (
    tester,
  ) async {
    final result = await _open(tester, (_, _) async {
      final request = RequestOptions(path: '/points');
      throw DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 403,
          data: {'message': 'لا يمكنك تعديل نقاط هذا الحساب'},
        ),
      );
    });

    await tester.enterText(_field('العدد'), '2');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('لا يمكنك تعديل نقاط هذا الحساب'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(result.value, isNull);
  });
}

void savingTests() {
  // Once the request is out, closing the dialog would hide whether it
  // landed: the user retries and the ledger gets a duplicate entry.
  testWidgets('cannot be dismissed while saving', (tester) async {
    final gate = Completer<void>();
    final result = await _open(tester, (_, _) => gate.future);

    await tester.enterText(_field('العدد'), '2');
    await tester.tap(find.text('حفظ'));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(result.value, isTrue);
  });
}
