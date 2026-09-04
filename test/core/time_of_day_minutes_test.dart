import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/time_of_day_minutes.dart';

void main() {
  test('constants', () {
    expect(dayStartMinutes, 360);
    expect(dayEndMinutes, 1320);
    expect(slotMinutes, 30);
    expect(slotsPerDay, 32);
  });

  group('formatMinutes', () {
    test('formats 06:00', () {
      expect(formatMinutes(360), '06:00');
    });

    test('formats 21:30', () {
      expect(formatMinutes(1290), '21:30');
    });
  });

  group('minutesOfDay', () {
    test('reads the hour and minute from a DateTime', () {
      expect(minutesOfDay(DateTime(2026, 1, 1, 10, 30)), 630);
    });
  });
}
