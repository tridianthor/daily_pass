import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/import_service.dart';
import '../../core/database/activities_dao.dart';
import '../../core/database/completions_dao.dart';
import '../../core/database/settings_dao.dart';
import '../../core/database/database_helper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: AppStrings.appearance),
          _ThemeSelector(
            value: settings.themeMode,
            onChanged: (mode) => ref.read(settingsProvider.notifier).setThemeMode(mode),
          ),
          _WeekStartSelector(
            value: settings.weekStartDay,
            onChanged: (day) => ref.read(settingsProvider.notifier).setWeekStartDay(day),
          ),
          const Divider(),
          _SectionHeader(title: AppStrings.dataManagement),
          const _DataManagementSection(),
          const Divider(),
          _SectionHeader(title: AppStrings.about),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppStrings.version),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text(AppStrings.theme),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
        ],
        selected: {value},
        onSelectionChanged: (selected) => onChanged(selected.first),
      ),
    );
  }
}

class _WeekStartSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _WeekStartSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.calendar_view_week),
      title: const Text(AppStrings.weekStart),
      trailing: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Sun')),
          ButtonSegment(value: 1, label: Text('Mon')),
        ],
        selected: {value},
        onSelectionChanged: (selected) => onChanged(selected.first),
      ),
    );
  }
}

class _DataManagementSection extends ConsumerStatefulWidget {
  const _DataManagementSection();

  @override
  ConsumerState<_DataManagementSection> createState() => _DataManagementSectionState();
}

class _DataManagementSectionState extends ConsumerState<_DataManagementSection> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text(AppStrings.exportData),
          onTap: _isExporting || _isImporting || _isClearing ? null : _exportData,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text(AppStrings.importData),
          onTap: _isExporting || _isImporting || _isClearing ? null : _importData,
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
          title: const Text(AppStrings.clearAllData, style: TextStyle(color: Colors.red)),
          onTap: _isExporting || _isImporting || _isClearing ? null : () => _showClearConfirmation(context),
        ),
      ],
    );
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final dbHelper = DatabaseHelper();
      final exportService = ExportService(
        ActivitiesDao(dbHelper),
        CompletionsDao(),
        SettingsDao(),
      );
      final path = await exportService.exportToFile();
      if (mounted) {
        if (path != null) {
          NotificationService.showSuccess(context, AppStrings.dataExported);
        } else {
          NotificationService.showInfo(context, 'Export cancelled');
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, AppStrings.exportFailed);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importData() async {
    setState(() => _isImporting = true);
    try {
      final dbHelper = DatabaseHelper();
      final importService = ImportService(
        dbHelper,
        ActivitiesDao(dbHelper),
        CompletionsDao(),
        SettingsDao(),
      );
      final result = await importService.importFromFile();
      if (mounted) {
        if (result.success) {
          NotificationService.showSuccess(context, AppStrings.activityImported(result.activityCount));
          ref.invalidate(activitiesProvider);
          ref.invalidate(allActivitiesProvider);
        } else {
          NotificationService.showError(context, result.errorMessage ?? AppStrings.importFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, AppStrings.importFailed);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _showClearConfirmation(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmClear),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.confirmClearMessage),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: AppStrings.deleteConfirmationHint,
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text == 'DELETE'),
            child: Text(AppStrings.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearAllData();
    }
    controller.dispose();
  }

  Future<void> _clearAllData() async {
    setState(() => _isClearing = true);
    try {
      final db = ref.read(databaseProvider);
      await db.clearAllData();
      ref.invalidate(activitiesProvider);
      ref.invalidate(allActivitiesProvider);
      if (mounted) {
        NotificationService.showWarning(context, AppStrings.dataCleared);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, AppStrings.somethingWentWrong);
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }
}
