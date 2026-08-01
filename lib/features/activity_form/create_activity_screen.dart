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

class CreateActivityScreen extends ConsumerStatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  ConsumerState<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends ConsumerState<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailController = TextEditingController();

  late int _dayOfWeek;

  @override
  void initState() {
    super.initState();
    // Default to the currently selected date's weekday
    // Normalize to midnight before using as provider key (per project rules)
    final selectedDate = ref.read(selectedDateProvider);
    final normalizedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    _dayOfWeek = normalizedDate.weekday % 7;
  }

  RepeatType _repeatType = RepeatType.none;
  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.createActivity),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
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

            RepeatSelector(
              value: _repeatType,
              onChanged: (type) => setState(() => _repeatType = type),
              dayOfWeek: _dayOfWeek,
              onDayOfWeekChanged: (day) => setState(() => _dayOfWeek = day ?? 0),
            ),
            const SizedBox(height: AppSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: LoadingButton(
                    onPressed: () async { context.pop(); },
                    child: const Text(AppStrings.cancel),
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

    final activityService = ref.watch(activityServiceProvider);
    await activityService.createActivity(
      name: _nameController.text.trim(),
      detail: _detailController.text.trim().isEmpty ? null : _detailController.text.trim(),
      repeatType: _repeatType,
      dayOfWeek: _repeatType == RepeatType.weekly ? _dayOfWeek : null,
    );

    ref.invalidate(activitiesProvider);
    ref.invalidate(allActivitiesProvider);

    if (mounted) {
      NotificationService.showSuccess(context, AppStrings.activityAdded);
      context.pop();
    }
  }
}
