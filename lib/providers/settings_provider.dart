import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../core/database/settings_dao.dart';

/// StateNotifier for managing app settings with persistence.
class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref ref;
  
  SettingsNotifier(this.ref) : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settingsDao = SettingsDao();
      final settings = await settingsDao.getSettings();
      state = settings;
    } catch (e) {
      // Keep default settings on error
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final newSettings = state.copyWith(themeMode: mode);
    state = newSettings;
    await _saveSettings(newSettings);
  }

  Future<void> setWeekStartDay(int day) async {
    final newSettings = state.copyWith(weekStartDay: day);
    state = newSettings;
    await _saveSettings(newSettings);
  }

  Future<void> setDefaultView(String view) async {
    final newSettings = state.copyWith(defaultView: view);
    state = newSettings;
    await _saveSettings(newSettings);
  }

  Future<void> resetSettings() async {
    state = const AppSettings();
    try {
      final settingsDao = SettingsDao();
      await settingsDao.resetSettings();
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }

  Future<void> _saveSettings(AppSettings settings) async {
    try {
      final settingsDao = SettingsDao();
      await settingsDao.saveSettings(settings);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}

/// Main settings provider.
/// Use this in your app: ref.watch(settingsProvider)
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

/// Convenience provider for theme mode.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

/// Convenience provider for week start day.
final weekStartDayProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).weekStartDay;
});

/// Convenience provider for default view.
final defaultViewProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).defaultView;
});
