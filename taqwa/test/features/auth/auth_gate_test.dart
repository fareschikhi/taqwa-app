import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/features/auth/presentation/pages/auth_gate.dart';
import 'package:taqwa/features/auth/presentation/pages/login_page.dart';

/// Stands in for the real notifier so a test can name the state the gate sees,
/// without a token store or an API behind it.
class _FixedAuth extends AuthNotifier {
  _FixedAuth(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

Widget _host(AuthState state) => ProviderScope(
  overrides: [authProvider.overrideWith(() => _FixedAuth(state))],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => const MaterialApp(home: AuthGate()),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Anything the gate shows may reach for the stored token on its way up.
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    TestDefaultBinaryMessenger(
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger,
    ).setMockMethodCallHandler(secureStorageChannel, (call) async => null);
  });

  testWidgets('waits rather than flashing the login form', (tester) async {
    await tester.pumpWidget(_host(AuthState(isLoading: true)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('shows the login form when no session was restored', (
    tester,
  ) async {
    await tester.pumpWidget(_host(AuthState()));
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  // The restored-session branch is not mounted here: every shell starts its
  // own fetches, which leave timers pending and make the test about the
  // harness rather than the gate. What the gate does with that state is
  // startup_destination_test and role_home_test between them.
}
