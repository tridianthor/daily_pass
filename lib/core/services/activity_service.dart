import 'package:uuid/uuid.dart';
import '../../models/activity.dart';
import '../../models/repeat_type.dart';
import '../../models/repeat_config.dart';
import '../database/activities_dao.dart';
import '../utils/repeat_utils.dart';

class ActivityService {
  final ActivitiesDao _activitiesDao;
  final Uuid _uuid = const Uuid();

  ActivityService(this._activitiesDao);

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
  }) async {
    final now = DateTime.now();
    
    // Calculate end date for limited repeats
    RepeatConfig? config;
    if (repeatType == RepeatType.forAWeek) {
      config = RepeatConfig(
        startDate: now,
        endDate: now.add(const Duration(days: 7)),
      );
    } else if (repeatType == RepeatType.forAMonth) {
      config = RepeatConfig(
        startDate: now,
        endDate: DateTime(now.year, now.month + 1, now.day),
      );
    }
    
    final activity = Activity(
      id: _uuid.v4(),
      name: name,
      detail: detail,
      repeatType: repeatType,
      repeatConfig: config,
      createdAt: now,
      updatedAt: now,
    );
    
    await _activitiesDao.insert(activity);
    return activity;
  }

  /// Update an existing activity
  Future<Activity> updateActivity({
    required String id,
    String? name,
    String? detail,
    RepeatType? repeatType,
    bool clearDetail = false,
  }) async {
    final existing = await _activitiesDao.getById(id);
    if (existing == null) {
      throw Exception('Activity not found: $id');
    }

    // Calculate end date for limited repeats
    RepeatConfig? config;
    if (repeatType == RepeatType.forAWeek) {
      config = RepeatConfig(
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      );
    } else if (repeatType == RepeatType.forAMonth) {
      final now = DateTime.now();
      config = RepeatConfig(
        startDate: now,
        endDate: DateTime(now.year, now.month + 1, now.day),
      );
    }

    final updated = existing.copyWith(
      name: name,
      detail: detail,
      repeatType: repeatType,
      repeatConfig: config,
      updatedAt: DateTime.now(),
      clearDetail: clearDetail,
    );

    await _activitiesDao.update(updated);
    return updated;
  }

  /// Delete an activity
  Future<void> deleteActivity(String id) async {
    await _activitiesDao.delete(id);
  }

  /// Delete all activities
  Future<void> deleteAllActivities() async {
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
