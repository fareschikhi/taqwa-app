import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/shared/presentation/widgets/change_password_sheet.dart';

Future<void> pumpSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: ChangePasswordSheet()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('rejects a new password under six characters', (tester) async {
    await pumpSheet(tester);

    expect(ChangePasswordSheet.validateNew('abc'), isNotNull);
    expect(ChangePasswordSheet.validateNew('abcdef'), isNull);
  });

  testWidgets('rejects a confirmation that does not match', (tester) async {
    await pumpSheet(tester);

    expect(ChangePasswordSheet.validateConfirm('abcdef', 'abcdeg'), isNotNull);
    expect(ChangePasswordSheet.validateConfirm('abcdef', 'abcdef'), isNull);
  });

  testWidgets('requires the current password', (tester) async {
    await pumpSheet(tester);

    expect(ChangePasswordSheet.validateCurrent(''), isNotNull);
    expect(ChangePasswordSheet.validateCurrent('123456'), isNull);
  });
}
