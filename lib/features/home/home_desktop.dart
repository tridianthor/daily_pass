import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../calendar/calendar_widget.dart';
import '../activity_list/activity_list_widget.dart';

class HomeDesktopLayout extends ConsumerWidget {
  const HomeDesktopLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Sidebar: Calendar + summary
        SizedBox(
          width: 280,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Column(
              children: [
                Expanded(child: CalendarWidget()),
                // Mini activity summary
                _ActivitySummary(),
              ],
            ),
          ),
        ),
        // Main: Activity list
        const Expanded(
          child: ActivityListWidget(),
        ),
      ],
    );
  }
}

class _ActivitySummary extends ConsumerWidget {
  const _ActivitySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final completionsAsync = ref.watch(completionsForDateProvider(selectedDate));

    return completionsAsync.when(
      data: (completions) {
        final completedCount = completions.values.where((c) => c.isCompleted).length;
        final totalCount = completions.length;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$completedCount / $totalCount completed',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      },
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox(height: 40),
    );
  }
}
