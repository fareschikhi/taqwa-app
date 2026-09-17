import 'package:taqwa/core/providers/auth_provider.dart';

/// What the app puts on screen when it opens, before anything is pushed.
enum StartupDestination {
  /// The stored token is still being read and turned back into a session.
  restoring,

  /// No usable session: the user signs in.
  login,

  /// A session was restored: the user goes to the home their role gets.
  home,
}

/// Where a launch with [state] belongs.
///
/// A restored session needs both halves: [AuthState.isAuthenticated] goes true
/// as soon as a token is found, but the cached profile is what says which home
/// to open, so a token with no profile behind it still starts at the login
/// screen rather than at a shell with nothing to draw.
StartupDestination startupDestinationFor(AuthState state) {
  if (state.isLoading) return StartupDestination.restoring;
  if (state.isAuthenticated && state.user != null) {
    return StartupDestination.home;
  }
  return StartupDestination.login;
}
