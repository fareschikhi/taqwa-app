import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/admin/presentation/admin_shell.dart';

void main() {
  testWidgets('opens the admin drawer through the shell scope', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: AdminShellScope(
            currentIndex: 1,
            selectTab: (_) {},
            openMenu: () => opened++,
            child: const Scaffold(body: Center(child: AdminMenuButton())),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    expect(opened, 1);
  });
}
