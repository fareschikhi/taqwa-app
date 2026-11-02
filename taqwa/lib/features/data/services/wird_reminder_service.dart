import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// What the user chose for the daily wird reminder on this phone.
class WirdReminderSettings {
  const WirdReminderSettings({required this.enabled, required this.time});

  final bool enabled;
  final TimeOfDay time;
}

enum WirdReminderResult { scheduled, permissionDenied, failed }

/// The daily "لا تنسَ وردك" notification.
///
/// It lives on the phone, not on the account: the reminder is about when this
/// person picks up this device, and scheduling it locally means it still
/// arrives with no signal and without the server knowing anything about it.
///
/// Scheduled inexactly, so Android may deliver it a few minutes late to save
/// battery. That is fine for a reminder and spares the app the exact-alarm
/// permission Google Play restricts.
class WirdReminderService {
  WirdReminderService._();

  static final WirdReminderService instance = WirdReminderService._();

  /// After isha for most people, and easy to move from the card.
  static const TimeOfDay defaultTime = TimeOfDay(hour: 20, minute: 0);

  static const int _notificationId = 7001;
  static const String _enabledKey = 'wird_reminder_enabled';
  static const String _minutesKey = 'wird_reminder_minutes';

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;

  /// No local notifications in the web build, so the card hides itself there.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<WirdReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_minutesKey);
    return WirdReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      time: minutes == null
          ? defaultTime
          : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
  }

  /// Turns the reminder on at [time], or moves it there if it was already on.
  /// Nothing is saved unless the notification was actually scheduled, so the
  /// card never claims a reminder the phone will not deliver.
  Future<WirdReminderResult> enable(TimeOfDay time) async {
    try {
      await _ensureInitialized();
      if (!await _requestPermission()) {
        return WirdReminderResult.permissionDenied;
      }
      await _plugin.cancel(id: _notificationId);
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'لا تنسَ وردك',
        body: 'حان وقت وردك اليومي من القرآن الكريم، ولو صفحة واحدة.',
        scheduledDate: _nextInstanceOf(time),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'wird_reminder',
            'تذكير الورد',
            channelDescription: 'تذكير يومي بقراءة وردك من القرآن الكريم',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      await _save(enabled: true, time: time);
      return WirdReminderResult.scheduled;
    } catch (_) {
      return WirdReminderResult.failed;
    }
  }

  /// Keeps the chosen time, so switching back on restores it.
  Future<void> disable(TimeOfDay time) async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(id: _notificationId);
    } finally {
      await _save(enabled: false, time: time);
    }
  }

  Future<void> _save({required bool enabled, required TimeOfDay time}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setInt(_minutesKey, time.hour * 60 + time.minute);
  }

  Future<void> _ensureInitialized() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // An unknown zone name leaves tz.local at UTC. The first reminder is
      // still placed at the right instant below; only a DST change would
      // shift later ones, and neither Algeria nor Saudi Arabia observes it.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Asked for when the user switches the reminder on, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      // Android 12 and older grant it at install and answer true here.
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Today at [time] if that is still ahead, otherwise tomorrow. Built from
  /// the device clock and converted, so it is the right instant even when the
  /// zone lookup fell back to UTC.
  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return tz.TZDateTime.from(next, tz.local);
  }
}
