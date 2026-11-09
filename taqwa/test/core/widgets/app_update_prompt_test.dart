import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:taqwa/core/utils/app_update.dart';
import 'package:taqwa/core/widgets/app_update_prompt.dart';

AppUpdateInfo _info(UpdateAvailability availability) => AppUpdateInfo(
  updateAvailability: availability,
  immediateUpdateAllowed: true,
  immediateAllowedPreconditions: null,
  flexibleUpdateAllowed: true,
  flexibleAllowedPreconditions: null,
  availableVersionCode: 2,
  installStatus: InstallStatus.unknown,
  packageName: 'com.eltaqwa.app',
  clientVersionStalenessDays: null,
  updatePriority: 0,
);

Widget _app(AppUpdateApi api) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (context, _) => MaterialApp(
    builder: (context, child) =>
        AppUpdatePrompt(api: api, enabled: true, child: child!),
    home: const Scaffold(body: SizedBox()),
  ),
);

void main() {
  testWidgets('offers a restart once the update is downloaded', (
    tester,
  ) async {
    var completed = 0;
    final api = AppUpdateApi(
      check: () async => _info(UpdateAvailability.updateAvailable),
      startFlexible: () async => AppUpdateResult.success,
      complete: () async => completed++,
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('نسخة جديدة من التطبيق جاهزة'), findsOneWidget);
    await tester.tap(find.text('إعادة التشغيل'));
    expect(completed, 1);
  });

  testWidgets('shows nothing when the app is up to date', (tester) async {
    final api = AppUpdateApi(
      check: () async => _info(UpdateAvailability.updateNotAvailable),
      startFlexible: () async => AppUpdateResult.success,
      complete: () async {},
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
