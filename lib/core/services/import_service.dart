import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../models/activity.dart';
import '../../models/completion.dart';
import '../../models/app_settings.dart';
import '../database/database_helper.dart';
import '../database/activities_dao.dart';
import '../database/completions_dao.dart';
import '../database/settings_dao.dart';

class ImportService {
  final DatabaseHelper _dbHelper;
  final ActivitiesDao _activitiesDao;
  final CompletionsDao _completionsDao;
  final SettingsDao _settingsDao;

  ImportService(this._dbHelper, this._activitiesDao, this._completionsDao, this._settingsDao);

  static const String _currentVersion = '1.0';

  /// Import data from a JSON map
  /// Returns ImportResult indicating success or error with details
  Future<ImportResult> importFromJson(Map<String, dynamic> data) async {
    try {
      // Validate schema version
      final version = data['version'] as String?;
      if (version == null) {
        return ImportResult.error('Missing version field in import data');
      }

      if (!_isVersionCompatible(version)) {
        return ImportResult.error(
          'Incompatible version: $version. Supported versions: $_currentVersion',
        );
      }

      // Validate required fields
      if (!data.containsKey('activities') || !data.containsKey('completions')) {
        return ImportResult.error('Missing required fields (activities, completions)');
      }

      // Parse data
      final activitiesList = data['activities'] as List<dynamic>;
      final completionsList = data['completions'] as List<dynamic>;
      final settingsData = data['settings'] as Map<String, dynamic>?;

      // Clear existing data before import
      await _dbHelper.clearAllData();

      // Import activities
      int activityCount = 0;
      for (final activityMap in activitiesList) {
        try {
          final activity = Activity.fromMap(activityMap as Map<String, dynamic>);
          await _activitiesDao.insert(activity);
          activityCount++;
        } catch (e) {
          // Skip invalid activity entries
          continue;
        }
      }

      // Import completions
      int completionCount = 0;
      for (final completionMap in completionsList) {
        try {
          final completion = Completion.fromMap(completionMap as Map<String, dynamic>);
          await _completionsDao.insert(completion);
          completionCount++;
        } catch (e) {
          // Skip invalid completion entries
          continue;
        }
      }

      // Import settings if present
      if (settingsData != null) {
        try {
          final settings = AppSettings.fromJson(settingsData);
          await _settingsDao.saveSettings(settings);
        } catch (e) {
          // Skip invalid settings, use defaults
        }
      }

      return ImportResult.success(
        activityCount: activityCount,
        completionCount: completionCount,
      );
    } catch (e) {
      return ImportResult.error('Import failed: ${e.toString()}');
    }
  }

  /// Import data from a JSON string
  Future<ImportResult> importFromString(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return await importFromJson(data);
    } catch (e) {
      return ImportResult.error('Invalid JSON: ${e.toString()}');
    }
  }

  /// Import data from a file using file picker
  Future<ImportResult> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.error('No file selected');
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      return await importFromString(jsonString);
    } catch (e) {
      return ImportResult.error('Failed to read file: ${e.toString()}');
    }
  }

  /// Preview import data without applying changes
  Future<ImportPreview?> previewImport(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate version
      final version = data['version'] as String?;
      if (version == null) {
        return null;
      }

      final activitiesList = data['activities'] as List<dynamic>?;
      final completionsList = data['completions'] as List<dynamic>?;

      return ImportPreview(
        version: version,
        activityCount: activitiesList?.length ?? 0,
        completionCount: completionsList?.length ?? 0,
        isCompatible: _isVersionCompatible(version),
      );
    } catch (e) {
      return null;
    }
  }

  bool _isVersionCompatible(String importedVersion) {
    // Currently only supporting exact version match
    // Can be extended for backward compatibility
    return importedVersion == _currentVersion;
  }
}

class ImportResult {
  final bool success;
  final int activityCount;
  final int completionCount;
  final String? errorMessage;

  const ImportResult._({
    required this.success,
    this.activityCount = 0,
    this.completionCount = 0,
    this.errorMessage,
  });

  factory ImportResult.success({
    required int activityCount,
    required int completionCount,
  }) {
    return ImportResult._(
      success: true,
      activityCount: activityCount,
      completionCount: completionCount,
    );
  }

  factory ImportResult.error(String message) {
    return ImportResult._(
      success: false,
      errorMessage: message,
    );
  }

  int get totalImported => activityCount + completionCount;
}

class ImportPreview {
  final String version;
  final int activityCount;
  final int completionCount;
  final bool isCompatible;

  const ImportPreview({
    required this.version,
    required this.activityCount,
    required this.completionCount,
    required this.isCompatible,
  });
}
