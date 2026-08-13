import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/main.dart';

void main() {
  // The login page already declares "required field" validators on both
  // inputs, but the submit handler has to actually run them. If it does not,
  // an empty form is sent to the API and the user is told their credentials
  // are wrong rather than that they left the fields blank.
  testWidgets('submitting an empty form shows the validators', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TaqwaApp());
    await tester.pumpAndSettle();

    expect(find.text('هذا الحقل مطلوب'), findsNothing);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    // One for the phone field, one for the password field.
    expect(find.text('هذا الحقل مطلوب'), findsNWidgets(2));
  });
}
