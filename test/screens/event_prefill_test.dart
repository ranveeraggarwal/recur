import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/screens/editor/event_prefill.dart';

CalendarEvent _event({
  String id = 'evt-1',
  String title = 'PT session',
  required DateTime start,
  int durationMinutes = 60,
  bool isAllDay = false,
  String? location,
  String? notes,
}) {
  return CalendarEvent(
    id: id,
    calendarId: 'cal-1',
    title: title,
    start: start,
    end: start.add(Duration(minutes: durationMinutes)),
    isAllDay: isAllDay,
    location: location,
    notes: notes,
  );
}

void main() {
  group('canPrefillFrom', () {
    test('accepts a plain timed event', () {
      expect(canPrefillFrom(_event(start: DateTime(2026, 9, 8, 10))), isTrue);
    });

    test('rejects all-day, untitled, and impossible durations', () {
      expect(
        canPrefillFrom(_event(start: DateTime(2026, 9, 8), isAllDay: true)),
        isFalse,
      );
      expect(
        canPrefillFrom(_event(title: '  ', start: DateTime(2026, 9, 8, 10))),
        isFalse,
      );
      expect(
        canPrefillFrom(
          _event(start: DateTime(2026, 9, 8, 10), durationMinutes: 2),
        ),
        isFalse,
      );
      expect(
        canPrefillFrom(
          _event(start: DateTime(2026, 9, 8, 8), durationMinutes: 600),
        ),
        isFalse,
      );
    });
  });

  group('prefillFor', () {
    test('copies every detail off the tapped event', () {
      final event = _event(
        start: DateTime(2026, 9, 8, 10, 0), // Tuesday
        durationMinutes: 45,
        location: 'Kungsholmen',
        notes: 'Bring the band',
      );

      final prefill = prefillFor(event: event, allEvents: [event])!;

      expect(prefill.name, 'PT session');
      expect(prefill.durationMinutes, 45);
      expect(prefill.location, 'Kungsholmen');
      expect(prefill.notes, 'Bring the band');
      expect(prefill.weekdays, {2});
      expect(prefill.windows, [
        const TimeWindow(startMinutes: 600, endMinutes: 660),
      ]);
      expect(prefill.sourceStart, DateTime(2026, 9, 8, 10, 0));
      expect(prefill.occurrences, 1);
    });

    test('takes the location from an older occurrence when the tapped one '
        'has none', () {
      final older = _event(
        id: 'a',
        start: DateTime(2026, 9, 1, 10),
        location: 'Kungsholmen',
        notes: 'Bring the band',
      );
      final tapped = _event(id: 'b', start: DateTime(2026, 9, 8, 10));

      final prefill = prefillFor(event: tapped, allEvents: [older, tapped])!;

      expect(prefill.location, 'Kungsholmen');
      expect(prefill.notes, 'Bring the band');
    });

    test('treats an empty location as missing, the way Android stores it', () {
      final older = _event(
        id: 'a',
        start: DateTime(2026, 9, 1, 10),
        location: 'Kungsholmen',
      );
      final tapped = _event(
        id: 'b',
        start: DateTime(2026, 9, 8, 10),
        location: '   ',
      );

      final prefill = prefillFor(event: tapped, allEvents: [older, tapped])!;

      expect(prefill.location, 'Kungsholmen');
    });

    test('the tapped occurrence wins over an older one', () {
      final older = _event(
        id: 'a',
        start: DateTime(2026, 9, 1, 10),
        location: 'Old gym',
      );
      final tapped = _event(
        id: 'b',
        start: DateTime(2026, 9, 8, 10),
        location: 'New gym',
      );

      final prefill = prefillFor(event: tapped, allEvents: [older, tapped])!;

      expect(prefill.location, 'New gym');
    });

    test('the most recent occurrence with a location fills the gap', () {
      final oldest = _event(
        id: 'a',
        start: DateTime(2026, 8, 18, 10),
        location: 'Old gym',
      );
      final middle = _event(
        id: 'b',
        start: DateTime(2026, 9, 1, 10),
        location: 'New gym',
      );
      final tapped = _event(id: 'c', start: DateTime(2026, 9, 8, 10));

      final prefill = prefillFor(
        event: tapped,
        allEvents: [oldest, middle, tapped],
      )!;

      expect(prefill.location, 'New gym');
    });

    test('the duration comes from the tapped occurrence, not the newest', () {
      final tapped = _event(
        id: 'a',
        start: DateTime(2026, 9, 1, 10),
        durationMinutes: 45,
      );
      final newer = _event(
        id: 'b',
        start: DateTime(2026, 9, 8, 10),
        durationMinutes: 90,
      );

      final prefill = prefillFor(event: tapped, allEvents: [tapped, newer])!;

      expect(prefill.durationMinutes, 45);
    });

    test('the weekdays and window come from every occurrence', () {
      final tuesday = _event(id: 'a', start: DateTime(2026, 9, 1, 10, 0));
      final thursday = _event(id: 'b', start: DateTime(2026, 9, 10, 17, 0));
      final tapped = _event(id: 'c', start: DateTime(2026, 9, 8, 10, 0));

      final prefill = prefillFor(
        event: tapped,
        allEvents: [tuesday, thursday, tapped],
      )!;

      expect(prefill.occurrences, 3);
      expect(prefill.weekdays, {2, 4});
      // 10:00 to 18:00 spans every occurrence.
      expect(prefill.windows, [
        const TimeWindow(startMinutes: 600, endMinutes: 1080),
      ]);
    });

    test('events with another name are not counted as occurrences', () {
      final other = _event(
        id: 'a',
        title: 'Physio',
        start: DateTime(2026, 9, 2, 17),
        location: 'Somewhere else',
      );
      final tapped = _event(id: 'b', start: DateTime(2026, 9, 8, 10));

      final prefill = prefillFor(event: tapped, allEvents: [other, tapped])!;

      expect(prefill.occurrences, 1);
      expect(prefill.weekdays, {2});
      expect(prefill.location, isNull);
    });

    test('rounds an odd duration to a multiple of five', () {
      final event = _event(
        start: DateTime(2026, 9, 8, 10),
        durationMinutes: 52,
      );

      expect(prefillFor(event: event, allEvents: [event])!.durationMinutes, 50);
    });

    test('returns null for an event that could not be a card', () {
      final event = _event(start: DateTime(2026, 9, 8), isAllDay: true);

      expect(prefillFor(event: event, allEvents: [event]), isNull);
    });

    test('pulls a window that runs past 22:00 back inside the day', () {
      final event = _event(
        start: DateTime(2026, 9, 8, 21, 30),
        durationMinutes: 60,
      );

      final window = prefillFor(
        event: event,
        allEvents: [event],
      )!.windows.single;

      expect(window.endMinutes, 1320);
      expect(window.startMinutes, 1260);
    });

    test('the window always holds the duration', () {
      final event = _event(
        start: DateTime(2026, 9, 8, 10),
        durationMinutes: 50,
      );

      final prefill = prefillFor(event: event, allEvents: [event])!;
      final window = prefill.windows.single;

      expect(
        window.endMinutes - window.startMinutes,
        greaterThanOrEqualTo(prefill.durationMinutes),
      );
    });

    test('clips a long name, location, and notes to the Editor limits', () {
      final event = _event(
        title: 'x' * 60,
        start: DateTime(2026, 9, 8, 10),
        location: 'y' * 120,
        notes: 'z' * 600,
      );

      final prefill = prefillFor(event: event, allEvents: [event])!;

      expect(prefill.name.length, 40);
      expect(prefill.location!.length, 80);
      expect(prefill.notes!.length, 500);
    });
  });
}
