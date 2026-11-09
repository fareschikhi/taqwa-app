import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/widgets/wird_reminder_card.dart';
import 'package:taqwa/features/data/services/wird_reminder_service.dart';

/// Stands in for the notification plugin and the phone's storage.
class _FakeService implements WirdReminderService {
  _FakeService({
    this.stored = const WirdReminderSettings(
      enabled: false,
      time: WirdReminderService.defaultTime,
    ),
    this.result = WirdReminderResult.scheduled,
  });

  WirdReminderSettings stored;
  WirdReminderResult result;
  final enabledAt = <TimeOfDay>[];
  int disabled = 0;
  final revision = ValueNotifier<int>(0);

  @override
  Listenable get changes => revision;

  @override
  Future<bool> shouldPrompt(int userId) async => false;

  @override
  Future<void> markPrompted(int userId) async {}

  @override
  Future<WirdReminderSettings> load() async => stored;

  @override
  Future<WirdReminderResult> enable(TimeOfDay time) async {
    enabledAt.add(time);
    return result;
  }

  @override
  Future<void> disable(TimeOfDay time) async => disabled++;
}

Future<void> _pump(WidgetTester tester, _FakeService service) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: ListView(children: [WirdReminderCard(service: service)]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('formats the time the way it is said', () {
    expect(formatWirdTime(const TimeOfDay(hour: 20, minute: 0)), '8:00 م');
    expect(formatWirdTime(const TimeOfDay(hour: 5, minute: 7)), '5:07 ص');
    expect(formatWirdTime(const TimeOfDay(hour: 0, minute: 30)), '12:30 ص');
    expect(formatWirdTime(const TimeOfDay(hour: 12, minute: 0)), '12:00 م');
  });

  testWidgets('off: no time strip until the reminder is switched on', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, service);

    expect(find.text('وقت التذكير'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(service.enabledAt, [WirdReminderService.defaultTime]);
    expect(find.text('وقت التذكير'), findsOneWidget);
    expect(find.text('8:00 م'), findsOneWidget);
  });

  testWidgets('on: shows the saved time and switches off', (tester) async {
    final service = _FakeService(
      stored: const WirdReminderSettings(
        enabled: true,
        time: TimeOfDay(hour: 5, minute: 30),
      ),
    );
    await _pump(tester, service);

    expect(find.text('5:30 ص'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(service.disabled, 1);
    expect(find.text('وقت التذكير'), findsNothing);
  });

  testWidgets('denied permission stays off and says how to fix it', (
    tester,
  ) async {
    final service = _FakeService(
      result: WirdReminderResult.permissionDenied,
    );
    await _pump(tester, service);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.textContaining('الإشعارات مغلقة'), findsOneWidget);
  });

  testWidgets('picks up a change saved behind it by the sign-in popup', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, service);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    service.stored = const WirdReminderSettings(
      enabled: true,
      time: TimeOfDay(hour: 21, minute: 15),
    );
    service.revision.value++;
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('9:15 م'), findsOneWidget);
  });
}
