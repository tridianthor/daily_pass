class RepeatConfig {
  final int? dayOfWeek; // 0-6 (Sun-Sat)
  final int? weekPosition; // 1-5 (1st-5th week)
  final DateTime? startDate;
  final DateTime? endDate;
  final int? occurrences;

  const RepeatConfig({
    this.dayOfWeek,
    this.weekPosition,
    this.startDate,
    this.endDate,
    this.occurrences,
  });

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'weekPosition': weekPosition,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'occurrences': occurrences,
      };

  factory RepeatConfig.fromJson(Map<String, dynamic> json) => RepeatConfig(
        dayOfWeek: json['dayOfWeek'] as int?,
        weekPosition: json['weekPosition'] as int?,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        occurrences: json['occurrences'] as int?,
      );

  RepeatConfig copyWith({
    int? dayOfWeek,
    int? weekPosition,
    DateTime? startDate,
    DateTime? endDate,
    int? occurrences,
    bool clearDayOfWeek = false,
    bool clearWeekPosition = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearOccurrences = false,
  }) =>
      RepeatConfig(
        dayOfWeek: clearDayOfWeek ? null : (dayOfWeek ?? this.dayOfWeek),
        weekPosition:
            clearWeekPosition ? null : (weekPosition ?? this.weekPosition),
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        occurrences: clearOccurrences ? null : (occurrences ?? this.occurrences),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatConfig &&
          runtimeType == other.runtimeType &&
          dayOfWeek == other.dayOfWeek &&
          weekPosition == other.weekPosition &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          occurrences == other.occurrences;

  @override
  int get hashCode =>
      dayOfWeek.hashCode ^
      weekPosition.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      occurrences.hashCode;
}
