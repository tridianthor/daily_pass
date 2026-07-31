import 'package:sqflite/sqflite.dart';
import '../../models/activity.dart';
import '../../models/repeat_type.dart';
import 'database_helper.dart';

class ActivitiesDao {
  final DatabaseHelper _dbHelper;

  ActivitiesDao(this._dbHelper);

  Future<Database> get _db => _dbHelper.database;

  Future<List<Activity>> getAll() async {
    final db = await _db;
    final maps = await db.query(
      'activities',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Activity.fromMap(map)).toList();
  }

  Future<Activity?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Activity.fromMap(maps.first);
  }

  Future<List<Activity>> getByDate(DateTime date) async {
    final activities = await getAll();
    
    // Filter activities that should appear on this date based on repeat rules
    return activities.where((activity) {
      return _isActivityOnDate(activity, date);
    }).toList();
  }

  Future<List<Activity>> getRecurring() async {
    final activities = await getAll();
    
    return activities.where((activity) {
      return activity.repeatType != RepeatType.none;
    }).toList();
  }

  bool _isActivityOnDate(Activity activity, DateTime date) {
    final startDate = activity.repeatConfig?.startDate ?? activity.createdAt;
    final targetDate = DateTime(date.year, date.month, date.day);
    final activityStartDate = DateTime(startDate.year, startDate.month, startDate.day);
    
    // Activity starts after target date - don't show
    if (targetDate.isBefore(activityStartDate)) return false;
    
    // Check end date
    if (activity.repeatConfig?.endDate != null) {
      final endDate = DateTime(
        activity.repeatConfig!.endDate!.year,
        activity.repeatConfig!.endDate!.month,
        activity.repeatConfig!.endDate!.day,
      );
      if (targetDate.isAfter(endDate)) return false;
    }
    
    // Check occurrences limit
    if (activity.repeatConfig?.occurrences != null) {
      final daysDiff = targetDate.difference(activityStartDate).inDays;
      if (daysDiff >= activity.repeatConfig!.occurrences!) return false;
    }
    // Check repeat type
    switch (activity.repeatType) {
      case RepeatType.none:
        return targetDate.isAtSameMomentAs(activityStartDate);
      case RepeatType.daily:
      case RepeatType.forAWeek:
      case RepeatType.forAMonth:
        return true;
      case RepeatType.weekdays:
        final weekday = targetDate.weekday;
        return weekday >= 1 && weekday <= 5;
      case RepeatType.weekly:
        if (activity.repeatConfig?.dayOfWeek != null) {
          final targetWeekday = targetDate.weekday % 7;
          return targetWeekday == activity.repeatConfig!.dayOfWeek;
        }
        return targetDate.weekday == activityStartDate.weekday;
      case RepeatType.monthlyDate:
        return targetDate.day == activityStartDate.day;
      case RepeatType.monthlyWeekday:
        final dayOfWeek = activity.repeatConfig?.dayOfWeek;
        final weekPosition = activity.repeatConfig?.weekPosition;
        if (dayOfWeek != null && targetDate.weekday % 7 != dayOfWeek) return false;
        if (weekPosition != null) {
          final weekOfMonth = ((targetDate.day - 1) ~/ 7) + 1;
          return weekOfMonth == weekPosition;
        }
        return targetDate.day == activityStartDate.day;
    }
  }

  Future<void> insert(Activity activity) async {
    final db = await _db;
    await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Activity activity) async {
    final db = await _db;
    await db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete('activities');
  }

  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM activities');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
