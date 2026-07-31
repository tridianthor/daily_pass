import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/activities_provider.dart';
import '../../providers/completions_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_colors.dart';

/// Calendar widget using table_calendar package.
/// Displays month view with navigation, date selection, and completion indicators.
class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final weekStartDay = ref.watch(weekStartDayProvider);
    
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final weekendColor = colorScheme.error;
    final headerColor = colorScheme.onSurface;
    final chevronColor = colorScheme.primary;

    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: focusedMonth,
      selectedDayPredicate: (day) => isSameDay(selectedDate, day),
      startingDayOfWeek: weekStartDay == 0
          ? StartingDayOfWeek.sunday
          : StartingDayOfWeek.monday,
      calendarFormat: CalendarFormat.month,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: headerColor,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: chevronColor,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: chevronColor,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
        weekendStyle: TextStyle(
          color: weekendColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        selectedDecoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        defaultTextStyle: TextStyle(
          color: textColor,
        ),
        weekendTextStyle: TextStyle(
          color: weekendColor,
          fontWeight: FontWeight.w500,
        ),
        outsideDaysVisible: false,
        markersMaxCount: 1,
        markerDecoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        ref.read(selectedDateProvider.notifier).state = selectedDay;
        ref.read(focusedMonthProvider.notifier).state = DateTime(
          focusedDay.year,
          focusedDay.month,
          1,
        );
      },
      onPageChanged: (focusedDay) {
        ref.read(focusedMonthProvider.notifier).state = DateTime(focusedDay.year, focusedDay.month, 1);
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          return _DateIndicator(date: date);
        },
      ),
    );
  }
}

/// Internal widget that builds date indicators (green/red dots).
class _DateIndicator extends ConsumerWidget {
  final DateTime date;
  const _DateIndicator({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesForDateProvider(date));

    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) return const SizedBox.shrink();

        return FutureBuilder<List<bool>>(
          future: Future.wait(
            activities.map((a) async {
              final completions = await ref.read(completionsForDateProvider(date).future);
              return completions[a.id]?.isCompleted ?? false;
            }),
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            final allComplete = snapshot.data!.every((c) => c);
            final anyComplete = snapshot.data!.any((c) => c);

            if (!anyComplete) return const SizedBox.shrink();

            return Positioned(
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: allComplete
                      ? AppColors.success
                      : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
