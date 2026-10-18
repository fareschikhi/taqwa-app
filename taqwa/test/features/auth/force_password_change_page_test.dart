import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/features/auth/presentation/pages/force_password_change_page.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/shared/presentation/widgets/change_password_sheet.dart';

/// Records what the page asks of the session instead of touching storage.
class _RecordingAuth extends AuthNotifier {
  int passwordChangedCalls = 0;
  int logoutCalls = 0;

  @override
  AuthState build() => AuthState(
    user: UserModel(
      id: 1,
      fullName: 'أم خالد',
      role: UserRole.parent,
      mustChangePassword: true,
    ),
    isAuthenticated: true,
  );

  @override
  Future<void> passwordChanged() async => passwordChangedCalls++;

  @override
  Future<void> logout() async => logoutCalls++;
}

Future<_RecordingAuth> _pump(
  WidgetTester tester, {
  required ChangePasswordAction onSubmit,
}) async {
  // A phone-sized surface: on the default 800x600 the card runs past the
  // bottom and the buttons are never hit.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final auth = _RecordingAuth();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(() => auth)],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) =>
            MaterialApp(home: ForcePasswordChangePage(onSubmit: onSubmit)),
      ),
    ),
  );
  await tester.pump();
  return auth;
}

Future<void> _fillAndSave(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'temp123');
  await tester.enterText(find.byType(TextField).at(1), 'newpass1');
  await tester.enterText(find.byType(TextField).at(2), 'newpass1');
  await tester.tap(find.text('حفظ'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lets the user through once the password is replaced', (
    tester,
  ) async {
    String? sentCurrent;
    String? sentNew;
    final auth = await _pump(
      tester,
      onSubmit: ({required currentPassword, required newPassword}) async {
        sentCurrent = currentPassword;
        sentNew = newPassword;
      },
    );

    await _fillAndSave(tester);

    expect(sentCurrent, 'temp123');
    expect(sentNew, 'newpass1');
    expect(auth.passwordChangedCalls, 1);
  });

  testWidgets('keeps the user here when the change is refused', (tester) async {
    final auth = await _pump(
      tester,
      onSubmit: ({required currentPassword, required newPassword}) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/password'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/password'),
            data: {'message': 'كلمة المرور الحالية غير صحيحة'},
          ),
        );
      },
    );

    await _fillAndSave(tester);

    expect(find.text('كلمة المرور الحالية غير صحيحة'), findsOneWidget);
    expect(auth.passwordChangedCalls, 0);
  });

  // Someone handed the wrong account, or on a borrowed phone, needs a way out
  // that is not "set a password on an account that is not yours".
  testWidgets('offers a way to sign out instead', (tester) async {
    final auth = await _pump(
      tester,
      onSubmit: ({required currentPassword, required newPassword}) async {},
    );

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
  });
}
