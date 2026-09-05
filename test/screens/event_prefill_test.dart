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
  test('reads a card off one event', () {
    final prefills = prefillsFromEvents([
      _event(
        start: DateTime(2026, 9, 8, 10, 0), // Tuesday
        location: 'Kungsholmen',
        notes: 'Bring the band',
      ),
    ]);

    expect(prefills, hasLength(1));
    final prefill = prefills.single;
    expect(prefill.name, 'PT session');
    expect(prefill.durationMinutes, 60);
    expect(prefill.location, 'Kungsholmen');
    expect(prefill.notes, 'Bring the band');
    expect(prefill.weekdays, {2});
    expect(prefill.windows, [
      const TimeWindow(startMinutes: 600, endMinutes: 660),
    ]);
    expect(prefill.occurrences, 1);
    expect(prefill.latestStart, DateTime(2026, 9, 8, 10, 0));
  });

  test('groups occurrences of the same title', () {
    final prefills = prefillsFromEvents([
      _event(id: 'a', start: DateTime(2026, 9, 1, 10, 0)), // Tuesday
      _event(id: 'b', start: DateTime(2026, 9, 10, 17, 0)), // Thursday
      _event(id: 'c', start: DateTime(2026, 9, 8, 10, 0)), // Tuesday
    ]);

    expect(prefills, hasLength(1));
    final prefill = prefills.single;
    expect(prefill.occurrences, 3);
    expect(prefill.weekdays, {2, 4});
    expect(prefill.latestStart, DateTime(2026, 9, 10, 17, 0));
    // 10:00 to 18:00 spans every occurrence.
    expect(prefill.windows, [
      const TimeWindow(startMinutes: 600, endMinutes: 1080),
    ]);
  });

  test('the newest occurrence supplies the details', () {
    final prefills = prefillsFromEvents([
      _event(id: 'a', start: DateTime(2026, 9, 1, 10, 0), location: 'Old gym'),
      _event(
        id: 'b',
        start: DateTime(2026, 9, 8, 10, 0),
        durationMinutes: 45,
        location: 'New gym',
      ),
    ]);

    expect(prefills.single.durationMinutes, 45);
    expect(prefills.single.location, 'New gym');
  });

  test('sorts by the most recent occurrence, newest first', () {
    final prefills = prefillsFromEvents([
      _event(id: 'a', title: 'Physio', start: DateTime(2026, 9, 1, 10, 0)),
      _event(id: 'b', title: 'PT session', start: DateTime(2026, 9, 9, 10, 0)),
      _event(id: 'c', title: 'Haircut', start: DateTime(2026, 9, 5, 10, 0)),
    ]);

    expect(prefills.map((p) => p.name), ['PT session', 'Haircut', 'Physio']);
  });

  test('rounds an odd duration to a multiple of five', () {
    final prefills = prefillsFromEvents([
      _event(start: DateTime(2026, 9, 8, 10, 0), durationMinutes: 52),
    ]);

    expect(prefills.single.durationMinutes, 50);
  });

  test('skips all-day, untitled, and impossible durations', () {
    final prefills = prefillsFromEvents([
      _event(
        id: 'a',
        title: 'Holiday',
        start: DateTime(2026, 9, 8),
        durationMinutes: 1440,
        isAllDay: true,
      ),
      _event(id: 'b', title: '   ', start: DateTime(2026, 9, 8, 10, 0)),
      _event(
        id: 'c',
        title: 'Marathon',
        start: DateTime(2026, 9, 8, 8, 0),
        durationMinutes: 600,
      ),
      _event(
        id: 'd',
        title: 'Quick sync',
        start: DateTime(2026, 9, 8, 10, 0),
        durationMinutes: 2,
      ),
    ]);

    expect(prefills, isEmpty);
  });

  test('pulls a window that runs past 22:00 back inside the day', () {
    final prefills = prefillsFromEvents([
      _event(start: DateTime(2026, 9, 8, 21, 30), durationMinutes: 60),
    ]);

    final window = prefills.single.windows.single;
    expect(window.endMinutes, 1320);
    expect(window.startMinutes, 1260);
    expect(window.endMinutes - window.startMinutes, greaterThanOrEqualTo(60));
  });

  test('widens a window that is shorter than the duration', () {
    // 10:00-10:50 rounds out to 10:00-11:00, which already holds 50 min.
    final prefills = prefillsFromEvents([
      _event(start: DateTime(2026, 9, 8, 10, 0), durationMinutes: 50),
    ]);

    final prefill = prefills.single;
    final window = prefill.windows.single;
    expect(
      window.endMinutes - window.startMinutes,
      greaterThanOrEqualTo(prefill.durationMinutes),
    );
  });

  test('clips a long name, location, and notes to the Editor limits', () {
    final prefills = prefillsFromEvents([
      _event(
        title: 'x' * 60,
        start: DateTime(2026, 9, 8, 10, 0),
        location: 'y' * 120,
        notes: 'z' * 600,
      ),
    ]);

    expect(prefills.single.name.length, 40);
    expect(prefills.single.location!.length, 80);
    expect(prefills.single.notes!.length, 500);
  });

  test('offers at most maxPrefills cards', () {
    final events = [
      for (var i = 0; i < maxPrefills + 5; i++)
        _event(
          id: 'evt-$i',
          title: 'Event $i',
          start: DateTime(2026, 9, 1, 10, 0).add(Duration(days: i)),
        ),
    ];

    expect(prefillsFromEvents(events), hasLength(maxPrefills));
  });
}
