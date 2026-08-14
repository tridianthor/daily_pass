import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../core/database/activities_dao.dart';
import 'database_provider.dart';

/// Currently selected date for viewing activities.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Activities that should appear on the selected date.
/// Automatically refreshes when selectedDate changes.
final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final db = ref.watch(databaseProvider);
  final date = ref.watch(selectedDateProvider);
  final activitiesDao = ActivitiesDao(db);
  return activitiesDao.getByDate(date);
});

/// All activities in the database.
/// Useful for calendar indicators and activity management screens.
final allActivitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final db = ref.watch(databaseProvider);
  final activitiesDao = ActivitiesDao(db);
  return activitiesDao.getAll();
});

/// Provider for a single activity by ID.
final activityByIdProvider = FutureProvider.family<Activity?, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final activitiesDao = ActivitiesDao(db);
  return activitiesDao.getById(id);
});

/// Provider for activities that have repeat configurations (recurring).
final recurringActivitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final db = ref.watch(databaseProvider);
  final activitiesDao = ActivitiesDao(db);
  return activitiesDao.getRecurring();
});
