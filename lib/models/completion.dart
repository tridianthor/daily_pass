class Completion {
  final String id;
  final String activityId;
  final DateTime completedDate;
  final DateTime completedAt;
  final bool isCompleted;

  const Completion({
    required this.id,
    required this.activityId,
    required this.completedDate,
    required this.completedAt,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'activity_id': activityId,
        'completed_date': '${completedDate.year.toString().padLeft(4, '0')}-'
            '${completedDate.month.toString().padLeft(2, '0')}-'
            '${completedDate.day.toString().padLeft(2, '0')}',
        'completed_at': completedAt.toIso8601String(),
        'is_completed': isCompleted ? 1 : 0,
      };

  factory Completion.fromMap(Map<String, dynamic> map) => Completion(
        id: map['id'] as String,
        activityId: map['activity_id'] as String,
        completedDate: DateTime.parse(map['completed_date'] as String),
        completedAt: DateTime.parse(map['completed_at'] as String),
        isCompleted: (map['is_completed'] as int) == 1,
      );

  Completion copyWith({
    String? id,
    String? activityId,
    DateTime? completedDate,
    DateTime? completedAt,
    bool? isCompleted,
  }) =>
      Completion(
        id: id ?? this.id,
        activityId: activityId ?? this.activityId,
        completedDate: completedDate ?? this.completedDate,
        completedAt: completedAt ?? this.completedAt,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Completion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          activityId == other.activityId &&
          completedDate == other.completedDate &&
          completedAt == other.completedAt &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode =>
      id.hashCode ^
      activityId.hashCode ^
      completedDate.hashCode ^
      completedAt.hashCode ^
      isCompleted.hashCode;
}
