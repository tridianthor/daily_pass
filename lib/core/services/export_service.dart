import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../database/activities_dao.dart';
import '../database/completions_dao.dart';
import '../database/settings_dao.dart';

class ExportService {
  final ActivitiesDao _activitiesDao;
  final CompletionsDao _completionsDao;
  final SettingsDao _settingsDao;

  ExportService(this._activitiesDao, this._completionsDao, this._settingsDao);

  static const String _exportVersion = '1.0';

  /// Export all data to JSON
  Future<Map<String, dynamic>> exportToJson() async {
    final activities = await _activitiesDao.getAll();
    final completions = await _completionsDao.getAll();
    final settings = await _settingsDao.getSettings();

    return {
      'version': _exportVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'activities': activities.map((a) => a.toMap()).toList(),
      'completions': completions.map((c) => c.toMap()).toList(),
      'settings': settings.toJson(),
    };
  }

  /// Export all data to a JSON string
  Future<String> exportToJsonString() async {
    final data = await exportToJson();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Export and save to a file using file picker
  Future<String?> exportToFile() async {
    try {
      final jsonString = await exportToJsonString();
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Daily Pass Data',
        fileName: 'daily_pass_export_${_timestamp()}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);
        return result;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Export to app documents directory (auto-save)
  Future<String> exportToDocuments() async {
    final jsonString = await exportToJsonString();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = _timestamp();
    final file = File('${directory.path}/daily_pass_export_$timestamp.json');
    await file.writeAsString(jsonString);
    return file.path;
  }

  /// Get export statistics
  Future<ExportStats> getExportStats() async {
    final activities = await _activitiesDao.count();
    final completions = await _completionsDao.count();
    return ExportStats(
      activityCount: activities,
      completionCount: completions,
      exportedAt: DateTime.now(),
    );
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}

class ExportStats {
  final int activityCount;
  final int completionCount;
  final DateTime exportedAt;

  const ExportStats({
    required this.activityCount,
    required this.completionCount,
    required this.exportedAt,
  });
}
