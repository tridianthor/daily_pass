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
    
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final weekendColor = colorScheme.error;
    final headerColor = colorScheme.onSurface;
    final chevronColor = colorScheme.primary;

    return SingleChildScrollView(
      child: TableCalendar(
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
          markersMaxCount: 0, // Disable dots, we use background colors
          cellMargin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
          defaultBuilder: (context, day, focusedDay) => _DateCell(day: day),
          todayBuilder: (context, day, focusedDay) => _DateCell(day: day, isToday: true),
          selectedBuilder: (context, day, focusedDay) => _DateCell(day: day, isSelected: true),
        ),
      ),
    );
  }
}

/// Internal widget that builds date cells with background colors.
class _DateCell extends ConsumerWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;

  const _DateCell({
    required this.day,
    this.isToday = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(dateIndicatorProvider(day));
    
    return statusAsync.when(
      data: (status) => _buildCell(context, status),
      loading: () => _buildCell(context, DateIndicatorStatus.none),
      error: (_, __) => _buildCell(context, DateIndicatorStatus.none),
    );
  }

  Widget _buildCell(BuildContext context, DateIndicatorStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final weekendColor = colorScheme.error;
    final isWeekend = day.weekday == 6 || day.weekday == 7;
    
    Color? backgroundColor;
    Color textCol = isWeekend ? weekendColor : textColor;
    FontWeight fontWeight = FontWeight.normal;

    if (isSelected) {
      backgroundColor = AppColors.primary;
      textCol = Colors.white;
      fontWeight = FontWeight.w600;
    } else if (isToday) {
      backgroundColor = AppColors.primary.withValues(alpha: 0.3);
      textCol = textColor;
      fontWeight = FontWeight.w600;
    } else {
      // Apply pastel background based on status
      switch (status) {
        case DateIndicatorStatus.complete:
          backgroundColor = AppColors.pastelGreen;
          break;
        case DateIndicatorStatus.missed:
          backgroundColor = AppColors.pastelRed;
          break;
        case DateIndicatorStatus.incomplete:
          backgroundColor = AppColors.pastelPrimary;
          break;
        case DateIndicatorStatus.none:
        case DateIndicatorStatus.selected:
          // No background color
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textCol,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}
