import 'package:flutter_test/flutter_test.dart';
import 'package:daily_pass/models/activity.dart';
import 'package:daily_pass/models/repeat_type.dart';
import 'package:daily_pass/models/repeat_config.dart';

void main() {
  group('Activity model notification fields', () {
    final now = DateTime(2026, 8, 15, 10, 0);

    test('defaults useNotification and isNotificationPersistent to false', () {
      final activity = Activity(
        id: '1',
        name: 'Morning Workout',
        repeatType: RepeatType.daily,
        createdAt: now,
        updatedAt: now,
      );

      expect(activity.useNotification, isFalse);
      expect(activity.notificationTime, isNull);
      expect(activity.isNotificationPersistent, isFalse);
    });

    test('serializes and deserializes notification fields correctly', () {
      final activity = Activity(
        id: '2',
        name: 'Take Vitamin',
        repeatType: RepeatType.daily,
        useNotification: true,
        notificationTime: '06:00',
        isNotificationPersistent: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = activity.toMap();
      expect(map['use_notification'], 1);
      expect(map['notification_time'], '06:00');
      expect(map['is_notification_persistent'], 1);

      final reconstructed = Activity.fromMap(map);
      expect(reconstructed.useNotification, isTrue);
      expect(reconstructed.notificationTime, '06:00');
      expect(reconstructed.isNotificationPersistent, isTrue);
      expect(reconstructed, equals(activity));
    });

    test('copyWith updates notification properties and clears notificationTime if requested', () {
      final activity = Activity(
        id: '3',
        name: 'Read Book',
        repeatType: RepeatType.weekly,
        repeatConfig: const RepeatConfig(dayOfWeek: 1),
        useNotification: true,
        notificationTime: '08:30',
        isNotificationPersistent: false,
        createdAt: now,
        updatedAt: now,
      );

      final updated = activity.copyWith(
        isNotificationPersistent: true,
        notificationTime: '09:00',
      );
      expect(updated.isNotificationPersistent, isTrue);
      expect(updated.notificationTime, '09:00');
      expect(updated.useNotification, isTrue);

      final turnedOff = updated.copyWith(
        useNotification: false,
        clearNotificationTime: true,
      );
      expect(turnedOff.useNotification, isFalse);
      expect(turnedOff.notificationTime, isNull);
    });
  });
}
