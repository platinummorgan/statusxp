import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalReminderService {
  LocalReminderService._();

  static final LocalReminderService instance = LocalReminderService._();
  static const int _streakReminderId = 4101;
  static const int _weeklyRecapReminderId = 4102;
  static const String _weeklyRecapEnabledKey = 'weekly_recap_reminder_enabled';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String route)? _onTap;

  Future<void> initialize({void Function(String route)? onTap}) async {
    if (onTap != null) _onTap = onTap;
    if (kIsWeb || _initialized) return;
    tz_data.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith('/')) {
          AnalyticsService().logCustomEvent(
            eventName: 'local_notification_opened',
            parameters: {'route': payload},
          );
          _onTap?.call(payload);
        }
      },
    );
    _initialized = true;
  }

  Future<String?> launchPayload() async {
    if (kIsWeb) return null;
    await initialize();
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details?.notificationResponse?.payload;
    if (payload != null) {
      AnalyticsService().logCustomEvent(
        eventName: 'local_notification_opened',
        parameters: {'route': payload, 'cold_start': true},
      );
    }
    return payload;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    return await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  Future<void> updateStreakReminder({
    required bool enabled,
    required int currentStreak,
    required int reminderHour,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _notifications.cancel(id: _streakReminderId);
    if (!enabled || currentStreak < 2) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminderHour.clamp(0, 23),
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id: _streakReminderId,
      title: 'Keep your StatusXP streak alive',
      body: 'Complete a daily challenge before your streak resets.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'statusxp_streaks',
          'Streak reminders',
          channelDescription: 'Optional reminders to protect StatusXP streaks',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/engagement-hub',
    );
  }

  Future<bool> weeklyRecapReminderEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_weeklyRecapEnabledKey) ?? false;
  }

  Future<void> setWeeklyRecapReminder({
    required bool enabled,
    required bool hasWeeklyActivity,
    int reminderHour = 19,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_weeklyRecapEnabledKey, enabled);
    await updateWeeklyRecapReminder(
      enabled: enabled,
      hasWeeklyActivity: hasWeeklyActivity,
      reminderHour: reminderHour,
    );
  }

  Future<void> updateWeeklyRecapReminder({
    required bool enabled,
    required bool hasWeeklyActivity,
    int reminderHour = 19,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _notifications.cancel(id: _weeklyRecapReminderId);
    if (!enabled || !hasWeeklyActivity) return;

    final now = tz.TZDateTime.now(tz.local);
    var daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday < 0) daysUntilSunday += 7;
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysUntilSunday,
      reminderHour.clamp(0, 23),
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    await _notifications.zonedSchedule(
      id: _weeklyRecapReminderId,
      title: 'Your StatusXP week is ready',
      body: 'See your progress, standout unlocks, and what to play next.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'statusxp_weekly_recap',
          'Weekly recap',
          channelDescription: 'Optional weekly StatusXP progress recap',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/weekly-recap',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
