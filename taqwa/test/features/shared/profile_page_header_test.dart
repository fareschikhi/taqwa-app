import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/shared/presentation/pages/profile_page.dart';

class _FixedAuth extends AuthNotifier {
  _FixedAuth(this.user);
  final UserModel user;

  @override
  AuthState build() => AuthState(user: user, isAuthenticated: true);
}

Widget _host(Widget page, UserRole role) => ProviderScope(
  overrides: [
    authProvider.overrideWith(
      () => _FixedAuth(UserModel(id: 1, fullName: 'مدير', role: role)),
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(home: page),
  ),
);

void main() {
  // The admin shell has no app bar; without its menu button here the admin
  // could not leave the account page.
  testWidgets('shows the leading widget it is given', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProfilePage(role: 'admin', leading: Icon(Icons.menu)),
        UserRole.admin,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('the edit toggle sits below the page title', (tester) async {
    await tester.pumpWidget(
      _host(const ProfilePage(role: 'admin'), UserRole.admin),
    );
    await tester.pump();

    final title = tester.getRect(find.text('الحساب'));
    final edit = tester.getRect(find.text('تعديل'));
    expect(edit.top, greaterThanOrEqualTo(title.bottom));

    await tester.tap(find.text('تعديل'));
    await tester.pump();
    expect(find.text('إلغاء'), findsOneWidget);
  });
}
