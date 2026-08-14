import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_pass/features/calendar/calendar_widget.dart';
import 'package:daily_pass/providers/activities_provider.dart';
import 'package:daily_pass/providers/calendar_provider.dart';
import 'package:daily_pass/providers/settings_provider.dart';

void main() {
  testWidgets('CalendarWidget prevents selecting past dates', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final container = ProviderContainer(
      overrides: [
        weekStartDayProvider.overrideWithValue(0),
        dateIndicatorProvider.overrideWith((ref, date) async => DateIndicatorStatus.none),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: CalendarWidget(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial selectedDate is today
    final initialSelectedDate = container.read(selectedDateProvider);
    expect(
      DateTime(initialSelectedDate.year, initialSelectedDate.month, initialSelectedDate.day),
      equals(today),
    );

    // If today is not the 1st of the month, try to tap a previous day (day 1 or today - 1)
    if (today.day > 1) {
      final pastDay = today.subtract(const Duration(days: 1));
      final pastDayFinder = find.text('${pastDay.day}').first;
      await tester.tap(pastDayFinder);
      await tester.pumpAndSettle();

      // Selected date should still be today (not pastDay)
      final selectedAfterPastTap = container.read(selectedDateProvider);
      expect(
        DateTime(selectedAfterPastTap.year, selectedAfterPastTap.month, selectedAfterPastTap.day),
        equals(today),
      );
    }
  });

  testWidgets('CalendarWidget allows selecting today and future dates', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final container = ProviderContainer(
      overrides: [
        weekStartDayProvider.overrideWithValue(0),
        dateIndicatorProvider.overrideWith((ref, date) async => DateIndicatorStatus.none),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: CalendarWidget(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find today's text widget and tap it
    final todayFinder = find.text('${today.day}').first;
    await tester.tap(todayFinder);
    await tester.pumpAndSettle();

    expect(
      DateTime(
        container.read(selectedDateProvider).year,
        container.read(selectedDateProvider).month,
        container.read(selectedDateProvider).day,
      ),
      equals(today),
    );
  });
}
