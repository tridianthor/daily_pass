import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final int weekStartDay; // 0 = Sunday, 1 = Monday
  final String defaultView; // 'day', 'week', 'month'

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.weekStartDay = 0,
    this.defaultView = 'day',
  });

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.index,
        'weekStartDay': weekStartDay,
        'defaultView': defaultView,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
        weekStartDay: json['weekStartDay'] as int? ?? 0,
        defaultView: json['defaultView'] as String? ?? 'day',
      );

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? weekStartDay,
    String? defaultView,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        weekStartDay: weekStartDay ?? this.weekStartDay,
        defaultView: defaultView ?? this.defaultView,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          weekStartDay == other.weekStartDay &&
          defaultView == other.defaultView;

  @override
  int get hashCode =>
      themeMode.hashCode ^ weekStartDay.hashCode ^ defaultView.hashCode;
}
