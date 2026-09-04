import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/clock.dart';

void main() {
  group('SystemClock', () {
    test('returns the current time', () {
      final clock = SystemClock();
      final before = DateTime.now();
      final now = clock.now();
      final after = DateTime.now();
      expect(now.isBefore(before), isFalse);
      expect(now.isAfter(after), isFalse);
    });
  });

  group('FixedClock', () {
    test('returns the fixed time it was constructed with', () {
      final fixed = DateTime(2026, 9, 8, 10, 0);
      final clock = FixedClock(fixed);
      expect(clock.now(), fixed);
    });

    test('advance moves the clock forward by a duration', () {
      final clock = FixedClock(DateTime(2026, 9, 8, 10, 0));
      clock.advance(const Duration(hours: 2));
      expect(clock.now(), DateTime(2026, 9, 8, 12, 0));
    });

    test('setNow replaces the current time', () {
      final clock = FixedClock(DateTime(2026, 9, 8, 10, 0));
      clock.setNow(DateTime(2026, 9, 9, 8, 30));
      expect(clock.now(), DateTime(2026, 9, 9, 8, 30));
    });
  });
}
