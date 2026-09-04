import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/formatting.dart';
import 'package:recur/core/local_date.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(45), '45 min');
  });

  test('formatTime', () {
    expect(formatTime(600), '10:00');
  });

  test('formatDayShort', () {
    expect(formatDayShort(const LocalDate(2026, 9, 8)), 'Tue 8 Sep');
  });

  test('formatWeekOf', () {
    expect(formatWeekOf(const LocalDate(2026, 9, 7)), 'Week of 7 Sep');
  });

  test('formatDaySpan', () {
    expect(
      formatDaySpan(
        date: const LocalDate(2026, 9, 8),
        startMinutes: 600,
        endMinutes: 660,
      ),
      'Tue 8 Sep, 10:00 to 11:00',
    );
  });

  group('formatLastBooked', () {
    test('never booked', () {
      expect(
        formatLastBooked(latestStart: null, now: DateTime(2026, 9, 8, 9, 0)),
        'Not booked yet',
      );
    });

    test('same day', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 9, 8, 7, 0),
          now: DateTime(2026, 9, 8, 9, 0),
        ),
        'Last booked today',
      );
    });

    test('1 day, crossing midnight (23:00 yesterday, 01:00 today)', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 9, 7, 23, 0),
          now: DateTime(2026, 9, 8, 1, 0),
        ),
        'Last booked yesterday',
      );
    });

    test('3 days', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 9, 5, 12, 0),
          now: DateTime(2026, 9, 8, 9, 0),
        ),
        'Last booked 3 days ago',
      );
    });

    test('7 days -> 1 week', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 9, 1, 12, 0),
          now: DateTime(2026, 9, 8, 9, 0),
        ),
        'Last booked 1 week ago',
      );
    });

    test('20 days -> 2 weeks', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 8, 19, 12, 0),
          now: DateTime(2026, 9, 8, 9, 0),
        ),
        'Last booked 2 weeks ago',
      );
    });

    test('28 days -> 1 month', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 8, 11, 12, 0),
          now: DateTime(2026, 9, 8, 9, 0),
        ),
        'Last booked 1 month ago',
      );
    });

    test('65 days -> 2 months', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 7, 5, 12, 0),
          now: DateTime(2026, 9, 8, 9, 0),
        ),
        'Last booked 2 months ago',
      );
    });

    test('a future start is "Booked for"', () {
      expect(
        formatLastBooked(
          latestStart: DateTime(2026, 9, 8, 10, 0),
          now: DateTime(2026, 9, 1, 9, 0),
        ),
        'Booked for Tue 8 Sep',
      );
    });
  });
}
