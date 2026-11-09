import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/features/teacher/presentation/widgets/student_of_month_picker_dialog.dart';

import '../../../helpers/stub_api.dart';

Map<String, Object?> _candidate(
  int id,
  String name,
  String score, {
  bool top = false,
  int penalty = 0,
}) => {
  'studentId': id,
  'fullName': name,
  'avatar': null,
  'points': score,
  'finesPenalty': penalty,
  'score': score,
  'isTop': top,
};

Map<String, Object?> _pending(List<Map<String, Object?>> candidates) => {
  'halaqaId': 5,
  'halaqaName': 'حلقة النور',
  'month': '2026-11',
  'candidates': candidates,
};

/// Opens the prompt through the same entry point the shell uses.
Future<ValueNotifier<bool?>> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final result = ValueNotifier<bool?>(null);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result.value = await StudentOfMonthPrompt.maybeShow(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

AppButton _validateButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byType(AppButton));

void main() {
  setUp(StudentOfMonthPrompt.resetForTest);

  testWidgets('a single top scorer is pre-selected and validated in one tap', (
    tester,
  ) async {
    final api = StubApi.install((r) {
      if (r.path.contains('/pending')) {
        return (
          200,
          [
            _pending([
              _candidate(1, 'أحمد', '17', top: true, penalty: 3),
              _candidate(2, 'بلال', '5'),
            ]),
          ],
        );
      }
      return (201, {'id': 1});
    });
    final result = await _open(tester);

    expect(find.text('طالب شهر نوفمبر 2026'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
    // Only the top pool is listed until the teacher switches.
    expect(find.text('بلال'), findsNothing);

    await tester.tap(find.text('اعتماد طالب الشهر'));
    await tester.pumpAndSettle();

    final post = api.sent('POST', '/student-of-month').single;
    expect(jsonDecode(jsonEncode(post.data)), {'halaqaId': 5, 'studentId': 1});
    expect(result.value, isTrue);
    expect(find.byType(StudentOfMonthPickerDialog), findsNothing);
  });

  testWidgets('a tie leaves the choice open until the teacher picks one', (
    tester,
  ) async {
    StubApi.install(
      (r) => (
        200,
        [
          _pending([
            _candidate(1, 'أحمد', '17', top: true),
            _candidate(3, 'جابر', '17', top: true),
          ]),
        ],
      ),
    );
    await _open(tester);

    expect(find.textContaining('تعادل 2 طلاب'), findsOneWidget);
    expect(_validateButton(tester).onPressed, isNull);

    await tester.tap(find.text('جابر'));
    await tester.pump();
    expect(_validateButton(tester).onPressed, isNotNull);
  });

  testWidgets('the other tab lets the teacher choose a non-top student', (
    tester,
  ) async {
    final api = StubApi.install((r) {
      if (r.path.contains('/pending')) {
        return (
          200,
          [
            _pending([
              _candidate(1, 'أحمد', '17', top: true),
              _candidate(2, 'بلال', '5'),
            ]),
          ],
        );
      }
      return (201, {'id': 1});
    });
    await _open(tester);

    await tester.tap(find.text('طالب آخر (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بلال'));
    await tester.pump();
    await tester.tap(find.text('اعتماد طالب الشهر'));
    await tester.pumpAndSettle();

    final post = api.sent('POST', '/student-of-month').single;
    expect(jsonDecode(jsonEncode(post.data))['studentId'], 2);
  });

  testWidgets('"later" closes without a choice; it is asked again next time', (
    tester,
  ) async {
    final api = StubApi.install(
      (r) => (
        200,
        [
          _pending([_candidate(1, 'أحمد', '17', top: true)]),
        ],
      ),
    );
    final result = await _open(tester);

    await tester.tap(find.text('لاحقاً'));
    await tester.pumpAndSettle();
    expect(result.value, isFalse);
    expect(api.sent('POST', '/student-of-month'), isEmpty);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentOfMonthPickerDialog), findsOneWidget);
  });

  testWidgets('a server refusal stays in the dialog with its message', (
    tester,
  ) async {
    StubApi.install((r) {
      if (r.path.contains('/pending')) {
        return (
          200,
          [
            _pending([_candidate(1, 'أحمد', '17', top: true)]),
          ],
        );
      }
      return (409, {'message': 'تم اختيار طالب هذا الشهر مسبقاً'});
    });
    await _open(tester);

    await tester.tap(find.text('اعتماد طالب الشهر'));
    await tester.pumpAndSettle();
    expect(find.text('تم اختيار طالب هذا الشهر مسبقاً'), findsOneWidget);
    expect(find.byType(StudentOfMonthPickerDialog), findsOneWidget);
  });

  testWidgets('nothing pending opens nothing', (tester) async {
    StubApi.install((r) => (200, <Object>[]));
    final result = await _open(tester);
    expect(find.byType(StudentOfMonthPickerDialog), findsNothing);
    expect(result.value, isFalse);
  });
}
