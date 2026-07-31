import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import 'database_helper.dart';

class SettingsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<AppSettings> getSettings() async {
    final db = await _dbHelper.database;
    final maps = await db.query('settings', where: 'id = ?', whereArgs: [1]);
    
    if (maps.isEmpty) {
      return const AppSettings();
    }
    
    final row = maps.first;
    return AppSettings(
      themeMode: ThemeMode.values[row['theme_mode'] as int? ?? 0],
      weekStartDay: row['week_start_day'] as int? ?? 0,
      defaultView: row['default_view'] as String? ?? 'day',
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await _dbHelper.database;
    await db.update(
      'settings',
      {
        'theme_mode': settings.themeMode.index,
        'week_start_day': settings.weekStartDay,
        'default_view': settings.defaultView,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<void> resetSettings() async {
    final db = await _dbHelper.database;
    await db.update(
      'settings',
      {
        'theme_mode': 0,
        'week_start_day': 0,
        'default_view': 'day',
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
