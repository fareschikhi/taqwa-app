import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/features/auth/presentation/startup_destination.dart';
import 'package:taqwa/features/data/models/user_model.dart';

UserModel _user({UserRole role = UserRole.parent}) =>
    UserModel(id: 1, fullName: 'أم خالد', role: role);

void main() {
  test('holds the launch screen while the stored session is being read', () {
    final destination = startupDestinationFor(AuthState(isLoading: true));

    expect(destination, StartupDestination.restoring);
  });

  test('sends a restored session straight to its home', () {
    final destination = startupDestinationFor(
      AuthState(user: _user(), isAuthenticated: true),
    );

    expect(destination, StartupDestination.home);
  });

  test('asks an unauthenticated launch to sign in', () {
    final destination = startupDestinationFor(AuthState());

    expect(destination, StartupDestination.login);
  });

  test('asks to sign in when the flag is set but no user was cached', () {
    // checkAutoLogin trusts a stored token before it has a profile to go with
    // it. Routing on the flag alone would hand a shell a null user, which is
    // how the profile page ends up spinning forever.
    final destination = startupDestinationFor(
      AuthState(isAuthenticated: true),
    );

    expect(destination, StartupDestination.login);
  });
}
