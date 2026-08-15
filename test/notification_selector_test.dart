import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_pass/core/constants/app_strings.dart';
import 'package:daily_pass/features/activity_form/widgets/notification_selector.dart';

void main() {
  testWidgets('NotificationSelector shows segmented button and toggles options', (WidgetTester tester) async {
    bool useNotification = false;
    String notificationTime = '06:00';
    bool isPersistent = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return NotificationSelector(
                useNotification: useNotification,
                notificationTime: notificationTime,
                isPersistent: isPersistent,
                onNotificationToggled: (val) {
                  setState(() => useNotification = val);
                },
                onTimeChanged: (val) {
                  setState(() => notificationTime = val);
                },
                onPersistentChanged: (val) {
                  setState(() => isPersistent = val);
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial state: "Do not use notification" is selected, subform is not shown
    expect(find.text(AppStrings.notification), findsOneWidget);
    expect(find.text(AppStrings.doNotUseNotification), findsOneWidget);
    expect(find.text(AppStrings.useNotification), findsOneWidget);
    expect(find.text(AppStrings.persistentNotification), findsNothing);

    // Tap "Use notification"
    await tester.tap(find.text(AppStrings.useNotification));
    await tester.pumpAndSettle();

    expect(useNotification, isTrue);
    expect(find.text(AppStrings.persistentNotification), findsOneWidget);
    expect(find.text(AppStrings.notificationTime), findsOneWidget);

    // Tap the persistent notification checkbox
    await tester.tap(find.text(AppStrings.persistentNotification));
    await tester.pumpAndSettle();
    expect(isPersistent, isTrue);

    // Toggle back to "Do not use notification"
    await tester.tap(find.text(AppStrings.doNotUseNotification));
    await tester.pumpAndSettle();

    expect(useNotification, isFalse);
    expect(find.text(AppStrings.persistentNotification), findsNothing);
  });
}
