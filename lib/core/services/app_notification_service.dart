import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/activity.dart';
import '../../models/repeat_type.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse notificationResponse) async {
  debugPrint('Background notification action clicked: ${notificationResponse.actionId}, id: ${notificationResponse.id}');
  if (notificationResponse.actionId == AppNotificationService.dismissActionId && notificationResponse.id != null) {
    await AppNotificationService().cancelActivityNotificationById(notificationResponse.id!);
  }
}

class AppNotificationService {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String persistentChannelId = 'persistent_activity_channel';
  static const String persistentChannelName = 'Persistent Activity Reminders';
  static const String persistentChannelDescription = 'Undismissable notifications for daily activities';

  static const String regularChannelId = 'scheduled_activity_channel';
  static const String regularChannelName = 'Activity Reminders';
  static const String regularChannelDescription = 'Reminders for daily activities';

  static const String dismissActionId = 'dismiss_action';

  static final AndroidNotificationChannel _persistentChannel = AndroidNotificationChannel(
    persistentChannelId,
    persistentChannelName,
    description: persistentChannelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static final AndroidNotificationChannel _regularChannel = AndroidNotificationChannel(
    regularChannelId,
    regularChannelName,
    description: regularChannelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Timezone initialization error (fallback to local if test): $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );

    const LinuxInitializationSettings linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          debugPrint('Notification clicked: ${response.payload}, action: ${response.actionId}');
          if (response.actionId == dismissActionId && response.id != null) {
            await _notificationsPlugin.cancel(response.id!);
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _isInitialized = true;

      // Explicitly register Android channels with Importance.max
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(_persistentChannel);
          await androidPlugin.createNotificationChannel(_regularChannel);
        }
      }
    } catch (e) {
      debugPrint('Local notifications initialize error (expected in tests): $e');
    }
  }

  Future<void> requestPermissions() async {
    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
        try {
          await androidImplementation?.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('Exact alarm permission request failed (non-critical): $e');
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Request permissions error: $e');
    }
  }

  int getNotificationId(String activityId) {
    return activityId.hashCode.abs() % 2147483647;
  }

  /// Parses "HH:mm" string into hour and minute (defaults to 06:00)
  static ({int hour, int minute}) parseNotificationTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) {
      return (hour: 6, minute: 0);
    }
    final parts = timeStr.trim().split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 6;
      final minute = int.tryParse(parts[1]) ?? 0;
      return (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
    }
    return (hour: 6, minute: 0);
  }

  /// Calculate the next scheduled trigger date and time for an activity
  /// Returns null if the activity notification should not be scheduled (e.g. one-time activity in the past)
  static tz.TZDateTime? calculateNextTrigger({
    required Activity activity,
    tz.TZDateTime? currentLocalTime,
  }) {
    if (!activity.useNotification) return null;

    final now = currentLocalTime ?? tz.TZDateTime.now(tz.local);
    final parsedTime = parseNotificationTime(activity.notificationTime);
    final hour = parsedTime.hour;
    final minute = parsedTime.minute;

    final startDate = activity.repeatConfig?.startDate ?? activity.createdAt;
    final activityStartDateLocal = tz.TZDateTime(
      tz.local,
      startDate.year,
      startDate.month,
      startDate.day,
    );

    switch (activity.repeatType) {
      case RepeatType.none:
        // One-time activity
        final targetScheduledTime = tz.TZDateTime(
          tz.local,
          startDate.year,
          startDate.month,
          startDate.day,
          hour,
          minute,
        );

        // If scheduled time has already passed relative to now, do not trigger
        if (targetScheduledTime.isBefore(now)) {
          return null;
        }
        return targetScheduledTime;

      case RepeatType.daily:
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        // If today is before activity start date, start from activity start date
        if (scheduledDate.isBefore(activityStartDateLocal)) {
          scheduledDate = tz.TZDateTime(
            tz.local,
            startDate.year,
            startDate.month,
            startDate.day,
            hour,
            minute,
          );
        }

        // If scheduled time for today has passed, schedule for tomorrow
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        return scheduledDate;

      case RepeatType.weekly:
        final targetDayOfWeek = activity.repeatConfig?.dayOfWeek ?? (activity.createdAt.weekday % 7);
        // Start checking from today
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        // Ensure we find the next date matching targetDayOfWeek
        while ((scheduledDate.weekday % 7) != targetDayOfWeek || scheduledDate.isBefore(now) || scheduledDate.isBefore(activityStartDateLocal)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        return scheduledDate;

      case RepeatType.monthlyDate:
        final targetDay = startDate.day;
        var scheduledYear = now.year;
        var scheduledMonth = now.month;

        int daysInTargetMonth = DateTime(scheduledYear, scheduledMonth + 1, 0).day;
        int clampedDay = targetDay > daysInTargetMonth ? daysInTargetMonth : targetDay;

        var scheduledDate = tz.TZDateTime(
          tz.local,
          scheduledYear,
          scheduledMonth,
          clampedDay,
          hour,
          minute,
        );

        if (scheduledDate.isBefore(now) || scheduledDate.isBefore(activityStartDateLocal)) {
          scheduledMonth++;
          if (scheduledMonth > 12) {
            scheduledMonth = 1;
            scheduledYear++;
          }
          daysInTargetMonth = DateTime(scheduledYear, scheduledMonth + 1, 0).day;
          clampedDay = targetDay > daysInTargetMonth ? daysInTargetMonth : targetDay;
          scheduledDate = tz.TZDateTime(
            tz.local,
            scheduledYear,
            scheduledMonth,
            clampedDay,
            hour,
            minute,
          );
        }
        return scheduledDate;
    }
  }

  NotificationDetails _buildNotificationDetails({
    required bool isPersistent,
    required String title,
    String? body,
  }) {
    final androidDetails = AndroidNotificationDetails(
      isPersistent ? persistentChannelId : regularChannelId,
      isPersistent ? persistentChannelName : regularChannelName,
      channelDescription:
          isPersistent ? persistentChannelDescription : regularChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: isPersistent,
      autoCancel: !isPersistent,
      actions: isPersistent
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                dismissActionId,
                'Dismiss',
                cancelNotification: true,
                showsUserInterface: false,
              ),
            ]
          : null,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );
  }

  Future<void> scheduleActivityNotification(Activity activity) async {
    final notifId = getNotificationId(activity.id);

    await cancelActivityNotification(activity.id);

    if (!activity.useNotification) {
      debugPrint('Notification skipped for "${activity.name}": useNotification is false');
      return;
    }

    final nextTrigger = calculateNextTrigger(activity: activity);
    if (nextTrigger == null) {
      debugPrint('No upcoming notification trigger for activity: ${activity.name}');
      return;
    }

    debugPrint('Scheduling notification for "${activity.name}" at $nextTrigger (id: $notifId)');

    final notificationDetails = _buildNotificationDetails(
      isPersistent: activity.isNotificationPersistent,
      title: activity.name,
      body: activity.detail,
    );

    try {
      DateTimeComponents? matchComponents;
      switch (activity.repeatType) {
        case RepeatType.daily:
          matchComponents = DateTimeComponents.time;
          break;
        case RepeatType.weekly:
          matchComponents = DateTimeComponents.dayOfWeekAndTime;
          break;
        case RepeatType.monthlyDate:
          matchComponents = DateTimeComponents.dayOfMonthAndTime;
          break;
        case RepeatType.none:
          matchComponents = null;
          break;
      }

      await _notificationsPlugin.zonedSchedule(
        notifId,
        activity.name,
        activity.detail,
        nextTrigger,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: activity.id,
      );
      debugPrint('Successfully scheduled notification for "${activity.name}" at $nextTrigger (id: $notifId)');
    } on PlatformException catch (e) {
      debugPrint('PlatformException scheduling notification for "${activity.name}": code=${e.code}, message=${e.message}');
    } catch (e) {
      debugPrint('Failed to schedule notification for "${activity.name}": $e');
    }
  }

  Future<void> cancelActivityNotification(String activityId) async {
    final notifId = getNotificationId(activityId);
    try {
      await _notificationsPlugin.cancel(notifId);
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  Future<void> cancelActivityNotificationById(int notificationId) async {
    try {
      await _notificationsPlugin.cancel(notificationId);
    } catch (e) {
      debugPrint('Failed to cancel notification by id: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }
}
