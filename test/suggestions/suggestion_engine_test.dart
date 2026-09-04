import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/local_date.dart';
import 'package:recur/core/time_of_day_minutes.dart';
import 'package:recur/data/models/booking.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/suggestions/suggestion_engine.dart';
import 'package:recur/suggestions/suggestion_window.dart';

/// Builds a [Booking] starting at [start] and lasting [minutes], with
/// `end = LocalDate.fromDateTime(start).at(minutesOfDay(start) + minutes)`
/// so a booking whose minutes push past midnight naturally crosses into the
/// next calendar date. Ids are dummy values; nothing in the engine reads
/// them.
Booking booking(DateTime start, int minutes) {
  final end = LocalDate.fromDateTime(start).at(minutesOfDay(start) + minutes);
  return Booking(
    id: 'bk-${start.toIso8601String()}',
    eventTypeId: 'et1',
    start: start,
    end: end,
    calendarId: '1',
    calendarEventId: 'evt-${start.toIso8601String()}',
    createdAt: start,
  );
}

/// A card with a 60 minute duration and a Mon/Wed/Fri, 08:00-18:00
/// preference, unless overridden.
EventType card({
  int durationMinutes = 60,
  Set<int> preferredWeekdays = const {1, 3, 5},
  int preferredStartMinutes = 480,
  int preferredEndMinutes = 1080,
}) {
  return EventType(
    id: 'et1',
    name: 'PT session',
    durationMinutes: durationMinutes,
    preferredWeekdays: preferredWeekdays,
    preferredStartMinutes: preferredStartMinutes,
    preferredEndMinutes: preferredEndMinutes,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // Thursday. Every "past" booking below is well before this.
  final now = DateTime(2026, 9, 10, 12, 0);

  final preference = SuggestionWindow(
    weekdays: const {1, 3, 5},
    startMinutes: 480,
    endMinutes: 1080,
  );

  test('no bookings -> preference window', () {
    final window = suggestionWindowFor(
      eventType: card(),
      bookings: const [],
      now: now,
    );

    expect(window, preference);
  });

  test('two past bookings -> preference window', () {
    final bookings = [
      booking(DateTime(2026, 9, 7, 9, 0), 60), // Monday
      booking(DateTime(2026, 9, 9, 9, 0), 60), // Wednesday
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window, preference);
  });

  test('three past bookings -> pattern window', () {
    final bookings = [
      booking(DateTime(2026, 9, 8, 10, 0), 60), // Tuesday, 10:00-11:00
      booking(DateTime(2026, 9, 1, 10, 30), 60), // Tuesday, 10:30-11:30
      booking(DateTime(2026, 9, 3, 9, 0), 60), // Thursday, 09:00-10:00
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(
      window,
      SuggestionWindow(weekdays: const {2}, startMinutes: 510, endMinutes: 720),
    );
  });

  test('future bookings are ignored', () {
    final bookings = [
      booking(DateTime(2026, 9, 7, 9, 0), 60), // past, Monday
      booking(DateTime(2026, 9, 9, 9, 0), 60), // past, Wednesday
      booking(DateTime(2026, 9, 11, 9, 0), 60), // future
      booking(DateTime(2026, 9, 14, 9, 0), 60), // future
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window, preference);
  });

  test('only the three most recent past bookings count', () {
    final bookings = [
      // Two oldest: Sundays with a time span that would change the result
      // if they were wrongly counted.
      booking(DateTime(2026, 8, 16, 6, 0), 60), // Sunday
      booking(DateTime(2026, 8, 23, 6, 0), 60), // Sunday
      // Three most recent: same pattern as "three past bookings".
      booking(DateTime(2026, 9, 1, 10, 30), 60), // Tuesday
      booking(DateTime(2026, 9, 3, 9, 0), 60), // Thursday
      booking(DateTime(2026, 9, 8, 10, 0), 60), // Tuesday
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(
      window,
      SuggestionWindow(weekdays: const {2}, startMinutes: 510, endMinutes: 720),
    );
  });

  test('three different weekdays tie -> all three', () {
    final bookings = [
      booking(DateTime(2026, 9, 7, 9, 0), 60), // Monday
      booking(DateTime(2026, 9, 9, 9, 0), 60), // Wednesday
      booking(DateTime(2026, 9, 4, 9, 0), 60), // Friday
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window.weekdays, {1, 3, 5});
  });

  test('two-way tie with three bookings is impossible; two same one different '
      '-> pair only', () {
    final bookings = [
      booking(DateTime(2026, 8, 31, 9, 0), 60), // Monday
      booking(DateTime(2026, 9, 7, 9, 0), 60), // Monday
      booking(DateTime(2026, 9, 8, 9, 0), 60), // Tuesday
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window.weekdays, {1});
  });

  test('bookings given out of order are sorted by start', () {
    final oldest = booking(DateTime(2026, 8, 23, 6, 0), 60); // Sunday
    final third = booking(DateTime(2026, 9, 3, 8, 0), 60); // Thursday
    final second = booking(DateTime(2026, 9, 7, 9, 0), 60); // Monday
    final mostRecent = booking(DateTime(2026, 9, 8, 10, 0), 60); // Tuesday

    // Deliberately not in start order.
    final bookings = [third, mostRecent, oldest, second];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(
      window,
      SuggestionWindow(
        weekdays: const {1, 2, 4},
        startMinutes: 450,
        endMinutes: 690,
      ),
    );
  });

  test('padding clamps at 06:00', () {
    final bookings = [
      booking(DateTime(2026, 9, 8, 6, 15), 60), // Tuesday, 06:15-07:15
      booking(DateTime(2026, 9, 1, 9, 0), 60), // Tuesday, 09:00-10:00
      booking(DateTime(2026, 9, 3, 9, 30), 60), // Thursday, 09:30-10:30
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window.startMinutes, 360);
  });

  test('padding clamps at 22:00', () {
    final bookings = [
      booking(DateTime(2026, 9, 8, 20, 45), 60), // Tuesday, 20:45-21:45
      booking(DateTime(2026, 9, 1, 9, 0), 60), // Tuesday, 09:00-10:00
      booking(DateTime(2026, 9, 3, 9, 30), 60), // Thursday, 09:30-10:30
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window.endMinutes, 1320);
  });

  test(
    'booking crossing midnight counts end as 24:00 then clamps to 22:00',
    () {
      final bookings = [
        // Tuesday 23:00, 75 minutes long -> ends Wednesday 00:15.
        booking(DateTime(2026, 9, 8, 23, 0), 75),
        booking(DateTime(2026, 9, 1, 9, 0), 60), // Tuesday, 09:00-10:00
        booking(DateTime(2026, 9, 3, 9, 30), 60), // Thursday, 09:30-10:30
      ];

      final window = suggestionWindowFor(
        eventType: card(),
        bookings: bookings,
        now: now,
      );

      expect(
        window,
        SuggestionWindow(
          weekdays: const {2},
          startMinutes: 510,
          endMinutes: 1320,
        ),
      );
    },
  );

  test('window smaller than duration is kept, not replaced', () {
    final bookings = [
      booking(DateTime(2026, 9, 8, 7, 0), 30), // Tuesday, 07:00-07:30
      booking(DateTime(2026, 9, 3, 7, 0), 30), // Thursday, 07:00-07:30
      booking(DateTime(2026, 9, 1, 7, 0), 30), // Tuesday, 07:00-07:30
    ];

    final window = suggestionWindowFor(
      eventType: card(durationMinutes: 120),
      bookings: bookings,
      now: now,
    );

    expect(window.startMinutes, 390);
    expect(window.endMinutes, 480);
    expect(window.endMinutes - window.startMinutes, lessThan(120));
  });

  test('booking exactly at now is not past', () {
    final bookings = [
      booking(DateTime(2026, 9, 7, 9, 0), 60), // past, Monday
      booking(DateTime(2026, 9, 9, 9, 0), 60), // past, Wednesday
      booking(now, 60), // start == now: not past
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window, preference);
  });

  test('weekday uses local start', () {
    final bookings = [
      booking(DateTime(2026, 9, 7, 0, 30), 30), // Monday, 00:30
      booking(DateTime(2026, 8, 31, 9, 0), 60), // Monday
      booking(DateTime(2026, 8, 24, 9, 30), 60), // Monday
    ];

    final window = suggestionWindowFor(
      eventType: card(),
      bookings: bookings,
      now: now,
    );

    expect(window.weekdays, {1});
  });
}
