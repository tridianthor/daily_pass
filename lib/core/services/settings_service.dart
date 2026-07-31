import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_settings.dart';
import '../database/settings_dao.dart';

// DAO provider
final settingsDaoProvider = Provider<SettingsDao>((ref) => SettingsDao());

// Settings state provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsDaoProvider));
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsDao _dao;

  SettingsNotifier(this._dao) : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = await _dao.getSettings();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _dao.saveSettings(state);
  }

  Future<void> setWeekStartDay(int day) async {
    state = state.copyWith(weekStartDay: day);
    await _dao.saveSettings(state);
  }

  Future<void> setDefaultView(String view) async {
    state = state.copyWith(defaultView: view);
    await _dao.saveSettings(state);
  }

  Future<void> resetSettings() async {
    state = const AppSettings();
    await _dao.resetSettings();
  }

  Future<void> reload() async {
    await _loadSettings();
  }
}

class SettingsService {
  final SettingsDao _dao = SettingsDao();

  /// Get current settings
  Future<AppSettings> getSettings() async {
    return await _dao.getSettings();
  }

  /// Get theme mode
  Future<ThemeMode> getThemeMode() async {
    final settings = await _dao.getSettings();
    return settings.themeMode;
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    final settings = await _dao.getSettings();
    await _dao.saveSettings(settings.copyWith(themeMode: mode));
  }

  /// Get week start day
  Future<int> getWeekStartDay() async {
    final settings = await _dao.getSettings();
    return settings.weekStartDay;
  }

  /// Set week start day (0 = Sunday, 1 = Monday)
  Future<void> setWeekStartDay(int day) async {
    final settings = await _dao.getSettings();
    await _dao.saveSettings(settings.copyWith(weekStartDay: day));
  }

  /// Get default view
  Future<String> getDefaultView() async {
    final settings = await _dao.getSettings();
    return settings.defaultView;
  }

  /// Set default view ('day', 'week', 'month')
  Future<void> setDefaultView(String view) async {
    final settings = await _dao.getSettings();
    await _dao.saveSettings(settings.copyWith(defaultView: view));
  }

  /// Reset settings to defaults
  Future<void> resetSettings() async {
    await _dao.resetSettings();
  }

  /// Save all settings at once
  Future<void> saveSettings(AppSettings settings) async {
    await _dao.saveSettings(settings);
  }
}
