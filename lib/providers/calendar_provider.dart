import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../models/repeat_type.dart';
import 'activities_provider.dart';
import 'completions_provider.dart';

/// Focused month for calendar display.
/// Used to determine which month to show in the calendar view.
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Status indicator for a date on the calendar.
enum DateIndicatorStatus {
  /// No activities are scheduled for this date.
  none,
  
  /// All scheduled activities are completed.
  complete,
  
  /// Some activities are incomplete (future date).
  incomplete,
  
  /// Activities missed (past date with incomplete activities).
  missed,
  
  /// This date is currently selected (for UI highlighting).
  selected,
}

/// Check if an activity should appear on a given date.
/// Mirrors the logic from ActivitiesDao._isActivityOnDate
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
    final occurrences = activity.repeatConfig!.occurrences!;
    final start = activityStartDate;
    final daysDiff = targetDate.difference(start).inDays;
    
    switch (activity.repeatType) {
      case RepeatType.none:
        if (daysDiff != 0) return false;
        break;
      case RepeatType.daily:
      case RepeatType.forAWeek:
      case RepeatType.forAMonth:
        if (daysDiff >= occurrences) return false;
        break;
      case RepeatType.weekly:
        final weeks = daysDiff ~/ 7;
        if (weeks >= occurrences) return false;
        final dayOfWeek = activity.repeatConfig?.dayOfWeek;
        if (dayOfWeek != null && targetDate.weekday % 7 != dayOfWeek) return false;
        break;
      case RepeatType.monthlyDate:
        if (targetDate.day != activityStartDate.day) return false;
        final months = (targetDate.year - activityStartDate.year) * 12 + 
            (targetDate.month - activityStartDate.month);
        if (months >= occurrences) return false;
        break;
    }
  } else {
    // No occurrences limit - check by repeat type
    switch (activity.repeatType) {
      case RepeatType.none:
        if (targetDate != activityStartDate) return false;
        break;
      case RepeatType.daily:
      case RepeatType.forAWeek:
      case RepeatType.forAMonth:
        // Continues indefinitely (for week/month will be limited by endDate in _isActivityOnDate)
        break;
      case RepeatType.weekly:
        final dayOfWeek = activity.repeatConfig?.dayOfWeek;
        if (dayOfWeek != null && targetDate.weekday % 7 != dayOfWeek) return false;
        break;
      case RepeatType.monthlyDate:
        if (targetDate.day != activityStartDate.day) return false;
        break;
    }
  }
  return true;
}

/// Determines the indicator status for a given date.
/// Checks if activities are scheduled and their completion status.
final dateIndicatorProvider = FutureProvider.family<DateIndicatorStatus, DateTime>((ref, date) async {
  // Get the currently selected date to check if this date is selected
  final selectedDate = ref.watch(selectedDateProvider);
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final normalizedSelected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  
  if (normalizedDate == normalizedSelected) {
    return DateIndicatorStatus.selected;
  }
  
  // Get all activities
  final activities = await ref.watch(allActivitiesProvider.future);
  
  // Get completions for this date
  final completions = await ref.watch(completionsForDateProvider(date).future);
  
  // Filter activities that should appear on this date
  final activitiesOnDate = activities.where((a) => _isActivityOnDate(a, date)).toList();
  
  if (activitiesOnDate.isEmpty) {
    return DateIndicatorStatus.none;
  }
  
  // Check if all activities are completed
  final allComplete = activitiesOnDate.every((a) {
    final completion = completions[a.id];
    return completion?.isCompleted ?? false;
  });
  
  if (allComplete) {
    return DateIndicatorStatus.complete;
  }
  
  // Check if date is in the past (missed activities)
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (normalizedDate.isBefore(today)) {
    return DateIndicatorStatus.missed;
  }
  
  return DateIndicatorStatus.incomplete;
});

/// Provider for activities scheduled on a specific date.
/// Returns the list of activities that should appear on that date.
final activitiesForDateProvider = FutureProvider.family<List<Activity>, DateTime>((ref, date) async {
  final activities = await ref.watch(allActivitiesProvider.future);
  return activities.where((a) => _isActivityOnDate(a, date)).toList();
});

/// Provider to get completion statistics for a date range.
final completionStatsForRangeProvider = FutureProvider.family<Map<String, int>, DateTimeRange>((ref, range) async {
  final activities = await ref.watch(allActivitiesProvider.future);
  final completions = await ref.watch(completionsForDateProvider(range.start).future);
  
  int total = 0;
  int completed = 0;
  
  for (var date = range.start; !date.isAfter(range.end); date = date.add(const Duration(days: 1))) {
    final activitiesOnDate = activities.where((a) => _isActivityOnDate(a, date)).toList();
    for (final activity in activitiesOnDate) {
      total++;
      final completion = completions[activity.id];
      if (completion?.isCompleted ?? false) {
        completed++;
      }
    }
  }
  
  return {'total': total, 'completed': completed};
});

/// Helper class for date ranges
class DateTimeRange {
  final DateTime start;
  final DateTime end;
  
  const DateTimeRange({required this.start, required this.end});
}
