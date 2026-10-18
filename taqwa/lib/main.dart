import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/mobile_frame.dart';
import 'features/auth/presentation/pages/auth_gate.dart';

/// Runs in its own isolate when a message arrives with the app closed, so it
/// shares nothing with the running app and has to initialise Firebase itself.
///
/// Android draws the tray notification from the message payload without any
/// help from here. This exists so the isolate has a valid entry point, and is
/// where anything that must happen on delivery rather than on tap would go.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No generated options file: the google-services Gradle plugin puts the
  // project's identity into the Android build, and this reads it from there.
  // The web build has no such file and no push, so Firebase stays off there.
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const TaqwaApp());
}

class TaqwaApp extends StatelessWidget {
  const TaqwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          configureScreenUtilForMobileFrame(context);
          return MaterialApp(
            title: 'تقوى',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: const Locale('ar'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar'), Locale('en')],
            builder: (context, widget) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: MobileFrame(child: widget!),
              );
            },
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
