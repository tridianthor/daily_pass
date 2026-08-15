import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_button/loading_button.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/notification_service.dart';
import '../activity_list/activity_service_provider.dart';
import 'widgets/repeat_selector.dart';
import 'widgets/notification_selector.dart';

class EditActivityScreen extends ConsumerStatefulWidget {
  final String activityId;

  const EditActivityScreen({
    super.key,
    required this.activityId,
  });

  @override
  ConsumerState<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends ConsumerState<EditActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailController = TextEditingController();

  bool _isLoading = true;
  Activity? _activity;

  RepeatType _repeatType = RepeatType.none;
  bool _useNotification = false;
  String _notificationTime = '06:00';
  bool _isNotificationPersistent = false;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final activityService = ref.read(activityServiceProvider);
    final activity = await activityService.getActivityById(widget.activityId);
    if (mounted && activity != null) {
      setState(() {
        _activity = activity;
        _nameController.text = activity.name;
        _detailController.text = activity.detail ?? '';
        _repeatType = activity.repeatType;
        _useNotification = activity.useNotification;
        _notificationTime = activity.notificationTime ?? '06:00';
        _isNotificationPersistent = activity.isNotificationPersistent;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.editActivity),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_activity == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.editActivity),
        ),
        body: const Center(
          child: Text('Activity not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.editActivity),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Activity Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.activityName,
                hintText: AppStrings.activityNameHint,
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Activity Detail
            TextFormField(
              controller: _detailController,
              decoration: const InputDecoration(
                labelText: AppStrings.activityDetail,
                hintText: AppStrings.activityDetailHint,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: AppSpacing.md),

            // Repeat Selector
            RepeatSelector(
              value: _repeatType,
              onChanged: (type) => setState(() => _repeatType = type),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Notification Selector
            NotificationSelector(
              useNotification: _useNotification,
              notificationTime: _notificationTime,
              isPersistent: _isNotificationPersistent,
              onNotificationToggled: (val) => setState(() => _useNotification = val),
              onTimeChanged: (val) => setState(() => _notificationTime = val),
              onPersistentChanged: (val) =>
                  setState(() => _isNotificationPersistent = val),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: LoadingButton.outlined(
                    onPressed: () => _showDeleteConfirmation(),
                    child: const Text(AppStrings.delete),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: LoadingButton.filled(
                    onPressed: () => _saveActivity(),
                    child: const Text(AppStrings.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;
    if (_activity == null) return;

    final activityService = ref.read(activityServiceProvider);
    await activityService.updateActivity(
      id: widget.activityId,
      name: _nameController.text.trim(),
      detail: _detailController.text.trim().isEmpty ? null : _detailController.text.trim(),
      repeatType: _repeatType,
      useNotification: _useNotification,
      notificationTime: _useNotification ? _notificationTime : null,
      isNotificationPersistent: _useNotification && _isNotificationPersistent,
      clearDetail: _detailController.text.trim().isEmpty,
    );

    ref.invalidate(activitiesProvider);
    ref.invalidate(allActivitiesProvider);

    if (mounted) {
      context.pop();
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: const Text(AppStrings.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteActivity();
    }
  }

  Future<void> _deleteActivity() async {
    if (_activity == null) return;

    final activityService = ref.read(activityServiceProvider);
    await activityService.deleteActivity(widget.activityId);

    ref.invalidate(activitiesProvider);
    ref.invalidate(allActivitiesProvider);

    if (mounted) {
      NotificationService.showSuccess(context, AppStrings.activityDeleted);
      context.pop();
    }
  }
}
