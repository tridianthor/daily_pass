import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_pass/core/constants/app_strings.dart';
import 'package:daily_pass/features/activity_form/create_activity_screen.dart';
import 'package:daily_pass/providers/activities_provider.dart';

void main() {
  testWidgets('CreateActivityScreen renders notification segmented button and inputs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedDateProvider.overrideWith((ref) => DateTime(2026, 8, 15)),
        ],
        child: const MaterialApp(
          home: CreateActivityScreen(),
        ),
      ),
    );

    expect(find.text(AppStrings.createActivity), findsOneWidget);
    expect(find.text(AppStrings.activityName), findsOneWidget);
    expect(find.text(AppStrings.notification), findsOneWidget);
    expect(find.text(AppStrings.doNotUseNotification), findsOneWidget);
    expect(find.text(AppStrings.useNotification), findsOneWidget);

    // Sub-form is initially hidden
    expect(find.text(AppStrings.notificationTime), findsNothing);

    // Switch to "Use notification"
    await tester.tap(find.text(AppStrings.useNotification));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.notificationTime), findsOneWidget);
    expect(find.text(AppStrings.persistentNotification), findsOneWidget);
  });
}
