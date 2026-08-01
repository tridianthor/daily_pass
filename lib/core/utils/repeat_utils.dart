// ignore_for_file: unused_import
// TODO: Import actual models when available
// import '../models/repeat_type.dart';
// import '../models/repeat_config.dart';
// import '../models/activity.dart';

class RepeatUtils {
  /// Check if activity should appear on given date
  /// 
  /// [activity] - The activity to check (contains repeatType and repeatConfig)
  /// [date] - The date to check against
  /// 
  /// Returns true if the activity should appear on the given date
  static bool shouldAppearOnDate({
    required int repeatType, // 0=none, 1=daily, 2=weekly, 3=monthlyDate, 4=forAWeek, 5=forAMonth
    DateTime? startDate,
    DateTime? endDate,
    int? dayOfWeek,
    int? weekPosition,
    required DateTime date,
  }) {
    if (repeatType == 0) {
      return _isSameDay(startDate, date);
    }

    final effectiveStartDate = startDate ?? date;
    if (date.isBefore(effectiveStartDate)) return false;

    if (endDate != null && date.isAfter(endDate)) return false;

    switch (repeatType) {
      case 1: // daily
        return true;
      case 2: // weekly
        return date.weekday == (dayOfWeek ?? effectiveStartDate.weekday);
      case 3: // monthly by date
        return date.day == effectiveStartDate.day;
      case 4: // for a week (daily until endDate)
        return true;
      case 5: // for a month (daily until endDate)
        return true;
      default:
        return false;
    }
  }

  static bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

}
