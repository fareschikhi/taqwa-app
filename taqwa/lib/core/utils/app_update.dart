import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// What one update check ended in. The widget only has to act on [ready].
enum AppUpdateOutcome {
  /// Nothing newer on Play, or this install did not come from Play.
  none,

  /// The parent said no to Play's dialog. Don't ask again this session.
  declined,

  /// Play couldn't check or download. Try again on a later check.
  failed,

  /// The new version is downloaded. A restart installs it.
  ready,
}

/// The three Play calls the flow needs, so tests can stand in for Play.
class AppUpdateApi {
  const AppUpdateApi({
    required this.check,
    required this.startFlexible,
    required this.complete,
  });

  final Future<AppUpdateInfo> Function() check;
  final Future<AppUpdateResult> Function() startFlexible;
  final Future<void> Function() complete;

  static const play = AppUpdateApi(
    check: InAppUpdate.checkForUpdate,
    startFlexible: InAppUpdate.startFlexibleUpdate,
    complete: InAppUpdate.completeFlexibleUpdate,
  );
}

/// Asks Play for a newer version and downloads it in the background
/// (a "flexible" update), so the parent keeps using the app meanwhile.
///
/// Play shows its own "update available" dialog; the app only has to offer
/// the restart once the download finishes.
Future<AppUpdateOutcome> runFlexibleUpdate(AppUpdateApi api) async {
  try {
    final info = await api.check();

    // Downloaded on an earlier launch but never installed.
    if (info.installStatus == InstallStatus.downloaded) {
      return AppUpdateOutcome.ready;
    }
    if (info.updateAvailability != UpdateAvailability.updateAvailable ||
        !info.flexibleUpdateAllowed) {
      return AppUpdateOutcome.none;
    }

    // Completes once the download is done, not when the dialog closes.
    return switch (await api.startFlexible()) {
      AppUpdateResult.success => AppUpdateOutcome.ready,
      AppUpdateResult.userDeniedUpdate => AppUpdateOutcome.declined,
      AppUpdateResult.inAppUpdateFailed => AppUpdateOutcome.failed,
    };
  } catch (e) {
    // Sideloaded and .dev builds aren't known to Play, so the check throws.
    // An update prompt is never worth breaking the app over.
    debugPrint('In-app update check failed: $e');
    return AppUpdateOutcome.failed;
  }
}

/// Only Play-installed Android apps can update this way.
bool get canUseInAppUpdate =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
