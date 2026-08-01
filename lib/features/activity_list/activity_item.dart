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
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    // Normalize date to midnight for consistent provider keys
    final normalizedDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    
    final completionAsync = ref.watch(
      completionStatusProvider((widget.activity.id, normalizedDate)),
    );

    return completionAsync.when(
      data: (completion) => _buildContent(context, completion?.isCompleted ?? false, normalizedDate),
      loading: () => _buildLoading(),
      error: (_, __) => _buildContent(context, false, normalizedDate),
    );
  }

  Widget _buildLoading() {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Text(
                widget.activity.name,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isCompleted, DateTime normalizedDate) {
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
          await _toggleCompletion(!isCompleted, normalizedDate);
          return false;
        } else {
          return await _confirmDelete();
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteActivity();
          setState(() => _isDismissed = true);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: InkWell(
          onTap: () {
            if (_hasDetail) {
              setState(() => _isExpanded = !_isExpanded);
            } else {
              _toggleCompletion(!isCompleted, normalizedDate);
            }
          },
          onLongPress: _navigateToEdit,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                _CompletionCheckbox(
                  isCompleted: isCompleted,
                  onToggle: () => _toggleCompletion(!isCompleted, normalizedDate),
                ),
                const SizedBox(width: AppSpacing.md),
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
                      if (_isExpanded && _hasDetail)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            widget.activity.detail!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (_hasRepeatType)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Row(
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.activity.repeatType.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
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
  }

  bool get _hasDetail =>
      widget.activity.detail != null && widget.activity.detail!.isNotEmpty;

  bool get _hasRepeatType => widget.activity.repeatType != RepeatType.none;

  Future<void> _toggleCompletion(bool isCompleted, DateTime normalizedDate) async {
    try {
      final completionService = ref.read(completionServiceProvider);
      final activityId = widget.activity.id;

      if (isCompleted) {
        await completionService.markCompleted(activityId, normalizedDate);
      } else {
        await completionService.markNotCompleted(activityId, normalizedDate);
      }

      ref.invalidate(completionsForDateProvider(normalizedDate));
      ref.invalidate(completionStatusProvider((activityId, normalizedDate)));
      ref.invalidate(dateIndicatorProvider(normalizedDate));
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to update: $e');
      }
    }
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Delete "${widget.activity.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _deleteActivity() {
    ref.read(activityServiceProvider).deleteActivity(widget.activity.id);
    ref.invalidate(allActivitiesProvider);
    ref.invalidate(activitiesProvider);
    NotificationService.showSuccess(context, 'Activity deleted');
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
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isCompleted ? Colors.green : Colors.grey,
            width: 2,
          ),
          color: isCompleted ? Colors.green : Colors.transparent,
        ),
        child: isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Text(label, style: const TextStyle(color: Colors.white)),
              ]
            : [
                Text(label, style: const TextStyle(color: Colors.white)),
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}
