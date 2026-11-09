import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/wird_reminder_prompt.dart';
import 'package:taqwa/features/data/services/wird_reminder_service.dart';

/// Stands in for the notification plugin and the phone's storage.
class _FakeService implements WirdReminderService {
  _FakeService({
    this.prompted = const {},
    this.result = WirdReminderResult.scheduled,
  });

  final Set<int> prompted;
  WirdReminderResult result;
  final enabledAt = <TimeOfDay>[];
  final marked = <int>[];

  @override
  Listenable get changes => ValueNotifier<int>(0);

  @override
  Future<bool> shouldPrompt(int userId) async => !prompted.contains(userId);

  @override
  Future<void> markPrompted(int userId) async => marked.add(userId);

  @override
  Future<WirdReminderSettings> load() async => const WirdReminderSettings(
    enabled: false,
    time: WirdReminderService.defaultTime,
  );

  @override
  Future<WirdReminderResult> enable(TimeOfDay time) async {
    enabledAt.add(time);
    return result;
  }

  @override
  Future<void> disable(TimeOfDay time) async {}
}

/// A phone-shaped window, matching the design size ScreenUtil scales to.
void _usePhoneWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  _FakeService service, {
  int userId = 1,
}) async {
  _usePhoneWindow(tester);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: WirdReminderPrompt(
          userId: userId,
          service: service,
          enabled: true,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first home after sign-in asks for the time', (tester) async {
    final service = _FakeService();
    await _pump(tester, service);

    expect(find.text('وردك اليومي'), findsOneWidget);
    expect(find.text('8:00 م'), findsOneWidget);

    await tester.tap(find.text('حفظ الوقت'));
    await tester.pumpAndSettle();

    expect(service.marked, [1]);
    expect(service.enabledAt, [WirdReminderService.defaultTime]);
    expect(find.textContaining('سنذكّرك بوردك'), findsOneWidget);
  });

  testWidgets('closing the popup still turns the reminder on', (tester) async {
    final service = _FakeService();
    await _pump(tester, service);

    // Tap the barrier, outside the dialog.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('حفظ الوقت'), findsNothing);
    expect(service.marked, [1]);
    expect(service.enabledAt, [WirdReminderService.defaultTime]);
  });

  testWidgets('an account already asked on this phone sees no popup', (
    tester,
  ) async {
    final service = _FakeService(prompted: {1});
    await _pump(tester, service);

    expect(find.text('حفظ الوقت'), findsNothing);
    expect(service.enabledAt, isEmpty);
  });

  testWidgets('a refused permission is explained and not asked again', (
    tester,
  ) async {
    final service = _FakeService(result: WirdReminderResult.permissionDenied);
    await _pump(tester, service);

    await tester.tap(find.text('حفظ الوقت'));
    await tester.pumpAndSettle();

    expect(service.marked, [1]);
    expect(find.textContaining('الإشعارات مغلقة'), findsOneWidget);
  });

  testWidgets('web build: never prompts', (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: WirdReminderPrompt(
            userId: 1,
            service: service,
            enabled: false,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حفظ الوقت'), findsNothing);
    expect(service.marked, isEmpty);
  });
}
