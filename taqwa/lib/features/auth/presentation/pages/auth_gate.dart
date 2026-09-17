import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/features/auth/presentation/role_home.dart';
import 'package:taqwa/features/auth/presentation/startup_destination.dart';
import 'login_page.dart';

/// The app's first screen, and the only thing that decides whether a launch
/// starts signed in.
///
/// Watching [authProvider] is also what starts the restore: the notifier is
/// lazy, and its build() is where checkAutoLogin is kicked off, so nothing
/// reads the stored token until this widget asks for the state.
///
/// It stays at the root for the whole session rather than being replaced, so
/// signing out has somewhere to fall back to without anyone pushing a route.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return switch (startupDestinationFor(auth)) {
      StartupDestination.restoring => const _RestoringSession(),
      StartupDestination.login => const LoginPage(),
      StartupDestination.home => homeForRole(auth.user!.role),
    };
  }
}

/// Held for as long as the stored token takes to read — long enough to matter
/// on a cold start, short enough that a login form appearing and then being
/// swapped out would read as a bug.
class _RestoringSession extends StatelessWidget {
  const _RestoringSession();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
