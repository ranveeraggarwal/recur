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

  group('roundDownToSlot', () {
    test('rounds down to the slot mark below', () {
      expect(roundDownToSlot(605), 600);
    });

    test('leaves a value already on a mark alone', () {
      expect(roundDownToSlot(630), 630);
    });
  });

  group('roundUpToSlot', () {
    test('rounds up to the slot mark above', () {
      expect(roundUpToSlot(605), 630);
    });

    test('leaves a value already on a mark alone', () {
      expect(roundUpToSlot(630), 630);
    });
  });
}
