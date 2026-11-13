import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/halaqa_order_sheet.dart';

const _halaqas = [
  (id: 1, name: 'حلقة الفجر'),
  (id: 2, name: 'حلقة العصر'),
  (id: 3, name: 'حلقة الجامعي والكبار'),
];

/// Opens the sheet through its real entry point and records what it returned.
Future<void> _open(
  WidgetTester tester,
  void Function(List<int>? result) onResult,
) async {
  // A phone-sized screen, so all three rows fit under the sheet's header.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async =>
                  onResult(await HalaqaOrderSheet.show(context, _halaqas)),
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
  testWidgets('lists the halaqas in the order it was given', (tester) async {
    await _open(tester, (_) {});

    final y = [
      for (final h in _halaqas) tester.getCenter(find.text(h.name)).dy,
    ];
    expect(y[0] < y[1] && y[1] < y[2], isTrue);
  });

  testWidgets('dragging a halaqa to the top saves it first', (tester) async {
    List<int>? result;
    await _open(tester, (r) => result = r);

    final handle = find.byKey(const ValueKey('halaqa-order-handle-3'));
    final drag = await tester.startGesture(tester.getCenter(handle));
    // The handle drags at once; the row itself would need a long press.
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ الترتيب'));
    await tester.pumpAndSettle();

    expect(result, [3, 1, 2]);
  });

  testWidgets('the alphabetical button sorts by name before saving', (
    tester,
  ) async {
    List<int>? result;
    await _open(tester, (r) => result = r);

    await tester.tap(find.text('ترتيب أبجدي'));
    await tester.pump();
    await tester.tap(find.text('حفظ الترتيب'));
    await tester.pumpAndSettle();

    // الجامعي < العصر < الفجر
    expect(result, [3, 2, 1]);
  });

  testWidgets('closing without saving returns nothing', (tester) async {
    List<int>? result = [0];
    await _open(tester, (r) => result = r);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
