import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_widget.dart';
import '../activity_list/activity_list_widget.dart';

class HomeMobileLayout extends ConsumerWidget {
  const HomeMobileLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Top: Calendar (natural height, unclipped)
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: const CalendarWidget(),
        ),
        // Bottom half: Activity list
        const Expanded(
          child: ActivityListWidget(),
        ),
      ],
    );
  }
}
