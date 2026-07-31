import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/activities_provider.dart';
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
          color: AppColors.lightOnBackground,
        ),
        leftChevronIcon: const Icon(
          Icons.chevron_left,
          color: AppColors.primary,
        ),
        rightChevronIcon: const Icon(
          Icons.chevron_right,
          color: AppColors.primary,
        ),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: AppColors.lightOnBackground,
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
        weekendTextStyle: TextStyle(
          color: AppColors.lightOnBackground.withValues(alpha: 0.7),
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
        ref.read(focusedMonthProvider.notifier).state = focusedDay;
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
    final indicatorAsync = ref.watch(dateIndicatorProvider(date));

    return indicatorAsync.when(
      data: (status) {
        if (status == DateIndicatorStatus.none) {
          return const SizedBox();
        }
        return Positioned(
          bottom: 4,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status == DateIndicatorStatus.complete
                  ? AppColors.success
                  : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
