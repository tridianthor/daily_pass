enum RepeatType {
  none,
  daily,
  weekly,
  monthlyDate,
}

extension RepeatTypeExtension on RepeatType {
  String get displayName {
    switch (this) {
      case RepeatType.none:
        return 'No repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthlyDate:
        return 'Monthly';
    }
  }
}
