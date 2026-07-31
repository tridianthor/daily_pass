import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/notification_service.dart';
import 'activity_service_provider.dart';
import 'completion_service_provider.dart';

/// Individual activity item widget with completion checkbox, expandable detail,
/// and swipe actions for completing/deleting activities.
class ActivityItem extends ConsumerStatefulWidget {
  final Activity activity;
  final DateTime date;

  const ActivityItem({
    super.key,
    required this.activity,
    required this.date,
  });

  @override
  ConsumerState<ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends ConsumerState<ActivityItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Watch completion status for this specific activity and date
    final completionAsync = ref.watch(
      completionStatusProvider((widget.activity.id, widget.date)),
    );

    return completionAsync.when(
      data: (completion) {
        final isCompleted = completion?.isCompleted ?? false;

        return Dismissible(
          key: Key(widget.activity.id),
          direction: DismissDirection.horizontal,
          background: _SwipeBackground(
            color: isCompleted ? Colors.orange : Colors.green,
            icon: isCompleted ? Icons.undo : Icons.check,
            alignment: Alignment.centerLeft,
            label: isCompleted ? 'Undo' : 'Done',
          ),
          secondaryBackground: _SwipeBackground(
            color: Colors.red,
            icon: Icons.delete,
            alignment: Alignment.centerRight,
            label: 'Delete',
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Toggle completion
              await _toggleCompletion(!isCompleted);
              return false; // Don't dismiss, just toggle
            } else {
              // Delete with confirmation
              return await _confirmDelete();
            }
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              _deleteActivity();
            }
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: InkWell(
              onTap: _hasDetail
                  ? () => setState(() => _isExpanded = !_isExpanded)
                  : null,
              onLongPress: _navigateToEdit,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Custom checkbox
                    _CompletionCheckbox(
                      isCompleted: isCompleted,
                      onToggle: () => _toggleCompletion(!isCompleted),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.activity.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isCompleted
                                        ? Colors.grey
                                        : null,
                                  ),
                                ),
                              ),
                              if (_hasDetail)
                                Icon(
                                  _isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.grey,
                                ),
                            ],
                          ),
                          if (_hasRepeatType)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.activity.repeatType.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_isExpanded && _hasDetail)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  widget.activity.detail!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text(widget.activity.name),
        ),
      ),
      error: (_, __) => Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: Icon(Icons.error, color: Colors.red.shade400),
          title: Text(
            'Error loading status',
            style: TextStyle(color: Colors.red.shade400),
          ),
        ),
      ),
    );
  }

  bool get _hasDetail =>
      widget.activity.detail != null && widget.activity.detail!.isNotEmpty;

  bool get _hasRepeatType => widget.activity.repeatType != RepeatType.none;

  Future<void> _toggleCompletion(bool isCompleted) async {
    final completionService = ref.read(completionServiceProvider);
    await completionService.toggleCompletion(
      widget.activity.id,
      widget.date,
    );

    // Refresh providers to update UI
    ref.invalidate(completionsForDateProvider(widget.date));
    ref.invalidate(activitiesProvider);

    if (mounted) {
      if (isCompleted) {
        NotificationService.showSuccess(context, 'Great job!');
      } else {
        NotificationService.showInfo(context, 'Marked incomplete');
      }
    }
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Activity?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _deleteActivity() {
    final activityService = ref.read(activityServiceProvider);
    final deletedActivity = widget.activity;

    activityService.deleteActivity(widget.activity.id);
    ref.invalidate(activitiesProvider);

    NotificationService.showWithUndo(
      context,
      'Activity deleted',
      () {
        // Undo delete by recreating the activity
        activityService.createActivity(
          name: deletedActivity.name,
          detail: deletedActivity.detail,
          repeatType: deletedActivity.repeatType,
        );
        ref.invalidate(activitiesProvider);
      },
    );
  }

  void _navigateToEdit() {
    context.push('/edit/${widget.activity.id}');
  }
}

/// Custom styled checkbox for activity completion.
class _CompletionCheckbox extends StatelessWidget {
  final bool isCompleted;
  final VoidCallback onToggle;

  const _CompletionCheckbox({
    required this.isCompleted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(
            color: isCompleted ? Colors.green : Colors.grey.shade400,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          color: isCompleted ? Colors.green : Colors.transparent,
        ),
        child: isCompleted
            ? const Icon(
                Icons.check,
                size: 18,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

/// Swipe action background widget for Dismissible.
class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Alignment alignment;
  final String label;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.alignment,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}
