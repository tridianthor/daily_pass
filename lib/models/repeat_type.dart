enum RepeatType {
  none,
  daily,
  weekdays,
  weekly,
  monthlyDate,
  monthlyWeekday,
  forAWeek,
  forAMonth,
}

extension RepeatTypeExtension on RepeatType {
  String get displayName {
    switch (this) {
      case RepeatType.none:
        return 'No repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthlyDate:
        return 'Monthly';
      case RepeatType.monthlyWeekday:
        return 'Monthly (weekday)';
      case RepeatType.forAWeek:
        return 'For a week';
      case RepeatType.forAMonth:
        return 'For a month';
    }
  }
}
