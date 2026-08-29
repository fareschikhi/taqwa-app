import 'package:dio/dio.dart';
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

  testWidgets('shows a failure message inside the sheet, not behind it', (
    tester,
  ) async {
    // A failed change leaves the sheet open, and a SnackBar would render
    // underneath it, so the user would see nothing at all.
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: ChangePasswordSheet(
                onSubmit: ({
                  required String currentPassword,
                  required String newPassword,
                }) async {
                  throw DioException(
                    requestOptions: RequestOptions(path: '/auth/password'),
                    response: Response(
                      requestOptions: RequestOptions(path: '/auth/password'),
                      data: {'message': 'كلمة المرور الحالية غير صحيحة'},
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'wrongpass');
    await tester.enterText(find.byType(TextField).at(1), 'newpass1');
    await tester.enterText(find.byType(TextField).at(2), 'newpass1');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('كلمة المرور الحالية غير صحيحة'), findsOneWidget);
  });
}
