import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/app_notification_service.dart';

class NotificationSelector extends StatelessWidget {
  final bool useNotification;
  final String notificationTime;
  final bool isPersistent;
  final ValueChanged<bool> onNotificationToggled;
  final ValueChanged<String> onTimeChanged;
  final ValueChanged<bool> onPersistentChanged;

  const NotificationSelector({
    super.key,
    required this.useNotification,
    required this.notificationTime,
    required this.isPersistent,
    required this.onNotificationToggled,
    required this.onTimeChanged,
    required this.onPersistentChanged,
  });

  TimeOfDay get _currentTimeOfDay {
    final parsed = AppNotificationService.parseNotificationTime(notificationTime);
    return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
  }

  String _formatDisplayTime(BuildContext context) {
    final tod = _currentTimeOfDay;
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat.jm().format(dt);
  }

  Future<void> _pickTime(BuildContext context) async {
    final initial = _currentTimeOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      onTimeChanged('$hourStr:$minuteStr');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.notification,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text(AppStrings.doNotUseNotification),
                icon: Icon(Icons.notifications_off_outlined),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text(AppStrings.useNotification),
                icon: Icon(Icons.notifications_active_outlined),
              ),
            ],
            selected: {useNotification},
            onSelectionChanged: (Set<bool> selected) {
              if (selected.isNotEmpty) {
                final enable = selected.first;
                if (enable) {
                  AppNotificationService().requestPermissions();
                }
                onNotificationToggled(enable);
              }
            },
          ),
        ),
        if (useNotification) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text(AppStrings.notificationTime),
                    subtitle: Text(
                      _formatDisplayTime(context),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: OutlinedButton.icon(
                      onPressed: () => _pickTime(context),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text(AppStrings.selectTime),
                    ),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isPersistent,
                    onChanged: (val) => onPersistentChanged(val ?? false),
                    title: const Text(AppStrings.persistentNotification),
                    subtitle: const Text(AppStrings.persistentNotificationDesc),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
