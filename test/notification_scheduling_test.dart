import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:daily_pass/core/services/app_notification_service.dart';
import 'package:daily_pass/models/activity.dart';
import 'package:daily_pass/models/repeat_type.dart';
import 'package:daily_pass/models/repeat_config.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('AppNotificationService.parseNotificationTime', () {
    test('parses valid time string', () {
      final res = AppNotificationService.parseNotificationTime('08:30');
      expect(res.hour, 8);
      expect(res.minute, 30);
    });

    test('defaults to 06:00 on null or empty or invalid', () {
      expect(AppNotificationService.parseNotificationTime(null), (hour: 6, minute: 0));
      expect(AppNotificationService.parseNotificationTime(''), (hour: 6, minute: 0));
      expect(AppNotificationService.parseNotificationTime('invalid'), (hour: 6, minute: 0));
    });
  });

  group('AppNotificationService.calculateNextTrigger', () {
    test('returns null if activity.useNotification is false', () {
      final now = tz.TZDateTime(tz.local, 2026, 8, 15, 7, 0);
      final activity = Activity(
        id: '1',
        name: 'Task',
        repeatType: RepeatType.daily,
        useNotification: false,
        notificationTime: '06:00',
        createdAt: DateTime(2026, 8, 15, 7, 0),
        updatedAt: DateTime(2026, 8, 15, 7, 0),
      );

      final next = AppNotificationService.calculateNextTrigger(
        activity: activity,
        currentLocalTime: now,
      );
      expect(next, isNull);
    });

    test('one-time activity created today after 6 AM will NOT spawn notification today', () {
      // Current time is 7:00 AM, default notif time is 6:00 AM
      final now = tz.TZDateTime(tz.local, 2026, 8, 15, 7, 0);
      final activity = Activity(
        id: '2',
        name: 'Single Task',
        repeatType: RepeatType.none,
        useNotification: true,
        notificationTime: '06:00',
        createdAt: DateTime(2026, 8, 15, 7, 0),
        updatedAt: DateTime(2026, 8, 15, 7, 0),
      );

      final next = AppNotificationService.calculateNextTrigger(
        activity: activity,
        currentLocalTime: now,
      );
      expect(next, isNull);
    });

    test('one-time activity created today before configured time WILL spawn notification today', () {
      // Current time is 5:00 AM, configured time is 6:00 AM
      final now = tz.TZDateTime(tz.local, 2026, 8, 15, 5, 0);
      final activity = Activity(
        id: '3',
        name: 'Early Task',
        repeatType: RepeatType.none,
        useNotification: true,
        notificationTime: '06:00',
        createdAt: DateTime(2026, 8, 15, 5, 0),
        updatedAt: DateTime(2026, 8, 15, 5, 0),
      );

      final next = AppNotificationService.calculateNextTrigger(
        activity: activity,
        currentLocalTime: now,
      );
      expect(next, isNotNull);
      expect(next!.year, 2026);
      expect(next.month, 8);
      expect(next.day, 15);
      expect(next.hour, 6);
      expect(next.minute, 0);
    });

    test('daily activity created today after 6 AM schedules for tomorrow at 6 AM', () {
      // Current time is 8:00 AM today
      final now = tz.TZDateTime(tz.local, 2026, 8, 15, 8, 0);
      final activity = Activity(
        id: '4',
        name: 'Daily Routine',
        repeatType: RepeatType.daily,
        useNotification: true,
        notificationTime: '06:00',
        createdAt: DateTime(2026, 8, 15, 8, 0),
        updatedAt: DateTime(2026, 8, 15, 8, 0),
      );

      final next = AppNotificationService.calculateNextTrigger(
        activity: activity,
        currentLocalTime: now,
      );
      expect(next, isNotNull);
      expect(next!.year, 2026);
      expect(next.month, 8);
      expect(next.day, 16); // Tomorrow
      expect(next.hour, 6);
      expect(next.minute, 0);
    });

    test('weekly activity created at 7 AM with 5 AM notification skips today and schedules next week', () {
      // E.g. current time is Saturday 7 AM (2026-08-15 is Saturday, weekday 6 in DateTime = 6 % 7 = 6)
      final now = tz.TZDateTime(tz.local, 2026, 8, 15, 7, 0);
      final activity = Activity(
        id: '5',
        name: 'Weekly Workout',
        repeatType: RepeatType.weekly,
        repeatConfig: const RepeatConfig(dayOfWeek: 6), // Saturday
        useNotification: true,
        notificationTime: '05:00',
        createdAt: DateTime(2026, 8, 15, 7, 0),
        updatedAt: DateTime(2026, 8, 15, 7, 0),
      );

      final next = AppNotificationService.calculateNextTrigger(
        activity: activity,
        currentLocalTime: now,
      );
      expect(next, isNotNull);
      expect(next!.day, 22); // Saturday next week (15 + 7)
      expect(next.hour, 5);
      expect(next.minute, 0);
    });
  });
}
