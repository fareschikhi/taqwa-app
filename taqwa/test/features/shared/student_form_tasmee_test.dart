import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/student/student_model.dart';
import 'package:taqwa/features/shared/presentation/pages/student_form_page.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(home: child),
);

/// Same phone surface as the parent form tests: the test font draws Arabic
/// glyphs as full squares, so overflow reports are dropped. The form's card
/// also trips Flutter's "ListTile inside a DecoratedBox" paint warning for
/// every toggle it already had (the adult switch, the hadith boxes); that is
/// about ink splashes, not behaviour, so it is dropped too. Anything else
/// still fails.
void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('A RenderFlex overflowed') ||
        text.contains('ListTile is wrapped in a DecoratedBox')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

/// The form loads its halaqa and parent lists over the real client, which
/// fails in tests but leaves its timeout timer behind; unmounting and
/// waiting it out keeps the test from ending with a timer pending.
Future<void> _drainNetwork(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

Finder _tasmeeSwitch() => find.widgetWithText(SwitchListTile, 'برنامج التسميع');

void main() {
  testWidgets('the admin sees the tasmee switch, on for a student in it', (
    tester,
  ) async {
    _phoneScreen(tester);
    final student = StudentModel.fromJson({
      'id': 3,
      'user': {'fullName': 'أحمد'},
      'tracksTasmee': true,
    });

    await tester.pumpWidget(
      _host(StudentFormPage(student: student, canSetHadithBooks: true)),
    );
    await tester.pump();

    await tester.ensureVisible(_tasmeeSwitch());
    await tester.pump();
    expect(tester.widget<SwitchListTile>(_tasmeeSwitch()).value, isTrue);

    await tester.tap(_tasmeeSwitch());
    await tester.pump();
    expect(tester.widget<SwitchListTile>(_tasmeeSwitch()).value, isFalse);
    await _drainNetwork(tester);
  });

  // The backend refuses the flag from anyone but an admin, so a manager's
  // form never offers it.
  testWidgets('a manager does not see the tasmee switch', (tester) async {
    _phoneScreen(tester);

    await tester.pumpWidget(_host(const StudentFormPage(managerId: 2)));
    await tester.pump();

    expect(find.text('برنامج التسميع', skipOffstage: false), findsNothing);
    await _drainNetwork(tester);
  });
}
