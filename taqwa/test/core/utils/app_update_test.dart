import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:taqwa/core/utils/app_update.dart';

AppUpdateInfo _info({
  UpdateAvailability availability = UpdateAvailability.updateAvailable,
  bool flexibleAllowed = true,
  InstallStatus status = InstallStatus.unknown,
}) => AppUpdateInfo(
  updateAvailability: availability,
  immediateUpdateAllowed: true,
  immediateAllowedPreconditions: null,
  flexibleUpdateAllowed: flexibleAllowed,
  flexibleAllowedPreconditions: null,
  availableVersionCode: 2,
  installStatus: status,
  packageName: 'com.eltaqwa.app',
  clientVersionStalenessDays: null,
  updatePriority: 0,
);

void main() {
  late int starts;

  AppUpdateApi api(
    Future<AppUpdateInfo> Function() check, {
    AppUpdateResult result = AppUpdateResult.success,
  }) => AppUpdateApi(
    check: check,
    startFlexible: () async {
      starts++;
      return result;
    },
    complete: () async {},
  );

  setUp(() => starts = 0);

  test('downloads a newer version and reports it ready', () async {
    final outcome = await runFlexibleUpdate(api(() async => _info()));
    expect(outcome, AppUpdateOutcome.ready);
    expect(starts, 1);
  });

  test('does nothing when Play has no newer version', () async {
    final outcome = await runFlexibleUpdate(
      api(
        () async =>
            _info(availability: UpdateAvailability.updateNotAvailable),
      ),
    );
    expect(outcome, AppUpdateOutcome.none);
    expect(starts, 0);
  });

  test('does nothing when Play forbids a flexible update', () async {
    final outcome = await runFlexibleUpdate(
      api(() async => _info(flexibleAllowed: false)),
    );
    expect(outcome, AppUpdateOutcome.none);
    expect(starts, 0);
  });

  test('offers the restart for a download left from last time', () async {
    final outcome = await runFlexibleUpdate(
      api(() async => _info(status: InstallStatus.downloaded)),
    );
    expect(outcome, AppUpdateOutcome.ready);
    expect(starts, 0);
  });

  test('reports a parent saying no', () async {
    final outcome = await runFlexibleUpdate(
      api(() async => _info(), result: AppUpdateResult.userDeniedUpdate),
    );
    expect(outcome, AppUpdateOutcome.declined);
  });

  test('a build Play does not know about fails quietly', () async {
    final outcome = await runFlexibleUpdate(
      api(() async => throw Exception('ERROR_APP_NOT_OWNED')),
    );
    expect(outcome, AppUpdateOutcome.failed);
  });
}
