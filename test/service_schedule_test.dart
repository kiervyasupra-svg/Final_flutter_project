import 'package:flutter_test/flutter_test.dart';
import 'package:carwash_reservation/core/utils/service_schedule.dart';

void main() {
  group('ServiceSchedule', () {
    test('converts booking times to minutes after midnight', () {
      expect(ServiceSchedule.minutesAfterMidnight('08:00 AM'), 480);
      expect(ServiceSchedule.minutesAfterMidnight('12:00 PM'), 720);
      expect(ServiceSchedule.minutesAfterMidnight('12:00 AM'), 0);
      expect(ServiceSchedule.minutesAfterMidnight('not a time'), isNull);
    });

    test('marks elapsed slots unavailable only for the current date', () {
      final now = DateTime(2026, 10, 7, 12, 46);
      final today = DateTime(2026, 10, 7);

      expect(
        ServiceSchedule.isTimeSlotInPast(today, '11:00 AM', now: now),
        isTrue,
      );
      expect(
        ServiceSchedule.isTimeSlotInPast(today, '01:00 PM', now: now),
        isFalse,
      );
      expect(
        ServiceSchedule.isTimeSlotInPast(today, '12:46 PM', now: now),
        isTrue,
      );
      expect(
        ServiceSchedule.isTimeSlotInPast(
          DateTime(2026, 10, 8),
          '08:00 AM',
          now: now,
        ),
        isFalse,
      );
    });

    test('detects overlapping services and permits back-to-back services', () {
      expect(
        ServiceSchedule.intervalsOverlap(
          firstTimeSlot: '08:00 AM',
          firstDurationMinutes: 120,
          secondTimeSlot: '09:30 AM',
          secondDurationMinutes: 30,
        ),
        isTrue,
      );
      expect(
        ServiceSchedule.intervalsOverlap(
          firstTimeSlot: '08:00 AM',
          firstDurationMinutes: 90,
          secondTimeSlot: '09:30 AM',
          secondDurationMinutes: 30,
        ),
        isFalse,
      );
    });
  });
}
