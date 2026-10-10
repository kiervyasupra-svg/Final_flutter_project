class ServiceSchedule {
  const ServiceSchedule._();

  static const List<String> timeSlots = [
    '08:00 AM',
    '09:30 AM',
    '11:00 AM',
    '01:00 PM',
    '02:30 PM',
    '04:00 PM',
  ];

  static int? minutesAfterMidnight(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final meridiem = match.group(3)!.toUpperCase();
    if (hour == null ||
        minute == null ||
        hour < 1 ||
        hour > 12 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return (hour % 12 + (meridiem == 'PM' ? 12 : 0)) * 60 + minute;
  }

  static bool isTimeSlotInPast(
    DateTime date,
    String timeSlot, {
    DateTime? now,
  }) {
    final minutes = minutesAfterMidnight(timeSlot);
    if (minutes == null) return false;

    final currentTime = now ?? DateTime.now();
    if (date.year != currentTime.year ||
        date.month != currentTime.month ||
        date.day != currentTime.day) {
      return false;
    }

    final slotTime = DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
    return !slotTime.isAfter(currentTime);
  }

  static bool intervalsOverlap({
    required String firstTimeSlot,
    required int firstDurationMinutes,
    required String secondTimeSlot,
    required int secondDurationMinutes,
  }) {
    final firstStart = minutesAfterMidnight(firstTimeSlot);
    final secondStart = minutesAfterMidnight(secondTimeSlot);
    if (firstStart == null || secondStart == null) {
      return firstTimeSlot == secondTimeSlot;
    }
    return firstStart < secondStart + secondDurationMinutes &&
        secondStart < firstStart + firstDurationMinutes;
  }
}
