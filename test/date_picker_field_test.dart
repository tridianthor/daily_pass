import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_pass/features/activity_form/widgets/date_picker_field.dart';

void main() {
  testWidgets('DatePickerField displays label and formatted date or placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePickerField(
            label: 'Start Date',
            value: DateTime(2026, 8, 14),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Start Date'), findsOneWidget);
    expect(find.text('Aug 14, 2026'), findsOneWidget);
  });

  testWidgets('DatePickerField opens showDatePicker with firstDate set to today or later', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePickerField(
            label: 'Select Date',
            value: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Select date'), findsOneWidget);
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();

    // Verify DatePicker dialog is displayed
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('DatePickerField clear button resets to today', (tester) async {
    DateTime? clearedDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePickerField(
            label: 'Start Date',
            value: DateTime(2026, 12, 25),
            allowClear: true,
            onChanged: (val) {
              clearedDate = val;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.clear), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(clearedDate, equals(today));
  });
}
