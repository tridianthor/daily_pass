import 'dart:convert';
import 'repeat_type.dart';
import 'repeat_config.dart';

class Activity {
  final String id;
  final String name;
  final String? detail;
  final RepeatType repeatType;
  final RepeatConfig? repeatConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Activity({
    required this.id,
    required this.name,
    this.detail,
    required this.repeatType,
    this.repeatConfig,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'detail': detail,
        'repeat_type': repeatType.index,
        'repeat_config':
            repeatConfig != null ? jsonEncode(repeatConfig!.toJson()) : null,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Activity.fromMap(Map<String, dynamic> map) {
    // Handle old repeat_type values that no longer exist in the enum
    int repeatTypeIndex = map['repeat_type'] as int;
    // Old mapping: 0=none, 1=daily, 2=weekdays, 3=weekly, 4=monthlyDate, 5=monthlyWeekday, 6=forAWeek, 7=forAMonth
    // New mapping: 0=none, 1=daily, 2=weekly, 3=monthlyDate
    // Map old indices to new ones (or to none as fallback)
    RepeatType repeatType;
    if (repeatTypeIndex >= RepeatType.values.length) {
      // Fallback for indices that don't exist
      repeatType = RepeatType.none;
    } else {
      repeatType = RepeatType.values[repeatTypeIndex];
    }

    return Activity(
      id: map['id'] as String,
      name: map['name'] as String,
      detail: map['detail'] as String?,
      repeatType: repeatType,
      repeatConfig: map['repeat_config'] != null
          ? RepeatConfig.fromJson(
              jsonDecode(map['repeat_config'] as String) as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Activity copyWith({
    String? id,
    String? name,
    String? detail,
    RepeatType? repeatType,
    RepeatConfig? repeatConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDetail = false,
    bool clearRepeatConfig = false,
  }) =>
      Activity(
        id: id ?? this.id,
        name: name ?? this.name,
        detail: clearDetail ? null : (detail ?? this.detail),
        repeatType: repeatType ?? this.repeatType,
        repeatConfig:
            clearRepeatConfig ? null : (repeatConfig ?? this.repeatConfig),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          detail == other.detail &&
          repeatType == other.repeatType &&
          repeatConfig == other.repeatConfig &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      detail.hashCode ^
      repeatType.hashCode ^
      repeatConfig.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
