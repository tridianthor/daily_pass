import 'package:uuid/uuid.dart';
import '../../models/activity.dart';
import '../../models/repeat_type.dart';
import '../../models/repeat_config.dart';
import '../database/activities_dao.dart';
import '../utils/repeat_utils.dart';
import 'app_notification_service.dart';

class ActivityService {
  final ActivitiesDao _activitiesDao;
  final AppNotificationService _notificationService;
  final Uuid _uuid = const Uuid();

  ActivityService(this._activitiesDao, [AppNotificationService? notificationService])
      : _notificationService = notificationService ?? AppNotificationService();

  /// Get all activities
  Future<List<Activity>> getAllActivities() async {
    return await _activitiesDao.getAll();
  }

  /// Get activity by ID
  Future<Activity?> getActivityById(String id) async {
    return await _activitiesDao.getById(id);
  }

  /// Get activities scheduled for a specific date
  /// Uses RepeatConfig to determine if activity should appear on date
  Future<List<Activity>> getActivitiesForDate(DateTime date) async {
    final allActivities = await _activitiesDao.getAll();
    
    return allActivities.where((activity) {
      return RepeatUtils.shouldAppearOnDate(
        repeatType: activity.repeatType.index,
        startDate: activity.repeatConfig?.startDate,
        endDate: activity.repeatConfig?.endDate,
        dayOfWeek: activity.repeatConfig?.dayOfWeek,
        weekPosition: activity.repeatConfig?.weekPosition,
        date: date,
      );
    }).toList();
  }

  /// Create a new activity
  Future<Activity> createActivity({
    required String name,
    String? detail,
    RepeatType repeatType = RepeatType.none,
    int? dayOfWeek,
    bool useNotification = false,
    String? notificationTime,
    bool isNotificationPersistent = false,
    DateTime? createdAt,
  }) async {
    final now = DateTime.now();
    final activityDate = createdAt ?? now;
    
    // Calculate config for specific repeat types
    RepeatConfig? config;
    if (repeatType == RepeatType.weekly) {
      // Store the selected day of week (0=Sun, 1=Mon, ..., 6=Sat)
      config = RepeatConfig(
        dayOfWeek: dayOfWeek ?? 0,
      );
    }
    
    final activity = Activity(
      id: _uuid.v4(),
      name: name,
      detail: detail,
      repeatType: repeatType,
      repeatConfig: config,
      useNotification: useNotification,
      notificationTime: useNotification ? (notificationTime ?? '06:00') : null,
      isNotificationPersistent: useNotification && isNotificationPersistent,
      createdAt: activityDate,
      updatedAt: now,
    );
    await _activitiesDao.insert(activity);

    if (activity.useNotification) {
      await _notificationService.scheduleActivityNotification(activity);
    }

    return activity;
  }

  /// Update an existing activity
  Future<Activity> updateActivity({
    required String id,
    String? name,
    String? detail,
    RepeatType? repeatType,
    bool? useNotification,
    String? notificationTime,
    bool? isNotificationPersistent,
    bool clearDetail = false,
    bool clearNotificationTime = false,
  }) async {
    final existing = await _activitiesDao.getById(id);
    if (existing == null) {
      throw Exception('Activity not found: $id');
    }

    final effectiveUseNotif = useNotification ?? existing.useNotification;
    final effectiveNotifTime = effectiveUseNotif
        ? (clearNotificationTime ? '06:00' : (notificationTime ?? existing.notificationTime ?? '06:00'))
        : null;
    final effectivePersistent = effectiveUseNotif
        ? (isNotificationPersistent ?? existing.isNotificationPersistent)
        : false;

    final updated = existing.copyWith(
      name: name,
      detail: detail,
      repeatType: repeatType,
      useNotification: effectiveUseNotif,
      notificationTime: effectiveNotifTime,
      isNotificationPersistent: effectivePersistent,
      updatedAt: DateTime.now(),
      clearDetail: clearDetail,
      clearNotificationTime: !effectiveUseNotif || clearNotificationTime,
    );

    await _activitiesDao.update(updated);

    if (updated.useNotification) {
      await _notificationService.scheduleActivityNotification(updated);
    } else {
      await _notificationService.cancelActivityNotification(updated.id);
    }

    return updated;
  }

  /// Delete an activity
  Future<void> deleteActivity(String id) async {
    await _notificationService.cancelActivityNotification(id);
    await _activitiesDao.delete(id);
  }

  /// Delete all activities
  Future<void> deleteAllActivities() async {
    await _notificationService.cancelAllNotifications();
    await _activitiesDao.deleteAll();
  }

  /// Get activity count
  Future<int> getActivityCount() async {
    return await _activitiesDao.count();
  }

  /// Toggle repeat type for an activity
  Future<Activity> toggleRepeatType(String id, RepeatType newType) async {
    return await updateActivity(id: id, repeatType: newType);
  }
}
