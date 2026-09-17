import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No stored token, so AuthGate finishes restoring and hands over to the
  // login form rather than opening someone's shell.
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
  });

  // The login page already declares "required field" validators on both
  // inputs, but the submit handler has to actually run them. If it does not,
  // an empty form is sent to the API and the user is told their credentials
  // are wrong rather than that they left the fields blank.
  testWidgets('submitting an empty form shows the validators', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TaqwaApp());

    // The app now opens on AuthGate, which holds an indeterminate spinner
    // while the stored token is read. pumpAndSettle would wait on that
    // animation forever, so step past it a frame at a time first.
    for (var i = 0; i < 10 && find.byType(AppButton).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.text('هذا الحقل مطلوب'), findsNothing);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    // One for the phone field, one for the password field.
    expect(find.text('هذا الحقل مطلوب'), findsNWidgets(2));
  });
}
