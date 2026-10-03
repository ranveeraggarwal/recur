import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/calendar/fake_calendar_gateway.dart';
import 'package:recur/history/history_scan.dart';
import 'package:recur/history/occurrence.dart';

CalendarEvent _event(
  String id,
  DateTime start, {
  String? notes,
  int minutes = 60,
}) {
  return CalendarEvent(
    id: id,
    calendarId: 'cal-1',
    title: 'PT session',
    start: start,
    end: start.add(Duration(minutes: minutes)),
    isAllDay: false,
    notes: notes,
  );
}

void main() {
  // Monday.
  final now = DateTime(2026, 9, 7, 9);

  group('historyRings', () {
    test('widen from a week to a month to a year, without overlapping', () {
      final rings = historyRings(now);

      expect(rings, hasLength(3));
      expect(rings[0], [
        (from: DateTime(2026, 8, 31), to: DateTime(2026, 9, 14)),
      ]);
      expect(rings[1], [
        (from: DateTime(2026, 8, 8), to: DateTime(2026, 8, 31)),
        (from: DateTime(2026, 9, 14), to: DateTime(2026, 10, 7)),
      ]);
      expect(rings[2], [
        (from: DateTime(2025, 9, 7), to: DateTime(2026, 8, 8)),
        (from: DateTime(2026, 10, 7), to: DateTime(2027, 9, 7)),
      ]);
    });
  });

  group('collectOccurrences', () {
    test('keeps only events with a marker', () {
      final found = <String, Occurrence>{};
      collectOccurrences(found, [
        _event('e1', DateTime(2026, 9, 1, 10), notes: 'Recur - rcab001'),
        _event('e2', DateTime(2026, 9, 2, 10), notes: 'Bring a towel'),
        _event('e3', DateTime(2026, 9, 3, 10)),
      ]);

      expect(found.keys, ['ab001']);
      expect(found['ab001']!.eventId, 'e1');
    });

    test('counts copies of one event once, at the earliest', () {
      final found = <String, Occurrence>{};
      collectOccurrences(found, [
        _event('e2', DateTime(2026, 9, 8, 10), notes: 'Recur - rcab001'),
        _event('e1', DateTime(2026, 9, 1, 10), notes: 'Recur - rcab001'),
      ]);
      collectOccurrences(found, [
        _event('e3', DateTime(2026, 9, 15, 10), notes: 'Recur - rcab001'),
      ]);

      expect(found, hasLength(1));
      expect(found['ab001']!.eventId, 'e1');
    });
  });

  group('historiesFrom', () {
    test('splits past from upcoming at now, newest past first', () {
      final found = <String, Occurrence>{};
      collectOccurrences(found, [
        _event('e1', DateTime(2026, 8, 1, 10), notes: 'Recur - rcab001'),
        _event('e2', DateTime(2026, 9, 1, 10), notes: 'Recur - rcab002'),
        _event('e3', DateTime(2026, 9, 20, 10), notes: 'Recur - rcab003'),
        _event('e4', DateTime(2026, 9, 10, 10), notes: 'Recur - rcab004'),
        _event('e5', DateTime(2026, 9, 2, 10), notes: 'Recur - rccd001'),
      ]);

      final histories = historiesFrom(found.values, now);

      final ab = histories['ab']!;
      expect(ab.past.map((o) => o.eventId), ['e2', 'e1']);
      expect(ab.next!.eventId, 'e4');
      expect(ab.lineStart, DateTime(2026, 9, 10, 10));
      expect(histories['cd']!.lineStart, DateTime(2026, 9, 2, 10));
      expect(histories['cd']!.next, isNull);
    });
  });

  group('scanHistory', () {
    late FakeCalendarGateway calendar;

    setUp(() {
      calendar = FakeCalendarGateway();
    });

    test('reads all three rings when a card never settles', () async {
      calendar.events.add(
        _event('e1', DateTime(2026, 3, 2, 10), notes: 'Recur - rcab001'),
      );

      final snapshots = await scanHistory(
        calendar: calendar,
        now: now,
        cardCodes: {'ab'},
      ).toList();

      expect(snapshots.map((s) => s.ringsDone), [1, 2, 3]);
      expect(snapshots.map((s) => s.done), [false, false, true]);
      expect(snapshots.last.progress, 1);
      expect(calendar.listQueries, hasLength(5));
      expect(
        snapshots.last.historyFor('ab').lineStart,
        DateTime(2026, 3, 2, 10),
      );
      expect(snapshots.last.seenCardCodes, {'ab'});
    });

    test('stops early once every card has settled', () async {
      calendar.events.addAll([
        _event('e1', DateTime(2026, 9, 1, 10), notes: 'Recur - rcab001'),
        _event('e2', DateTime(2026, 9, 3, 10), notes: 'Recur - rcab002'),
        _event('e3', DateTime(2026, 9, 4, 10), notes: 'Recur - rcab003'),
        _event('e4', DateTime(2026, 9, 9, 10), notes: 'Recur - rcab004'),
      ]);

      final snapshots = await scanHistory(
        calendar: calendar,
        now: now,
        cardCodes: {'ab'},
      ).toList();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.done, isTrue);
      expect(calendar.listQueries, hasLength(1));
      final ab = snapshots.single.historyFor('ab');
      expect(ab.past, hasLength(3));
      expect(ab.next!.eventId, 'e4');
    });

    test('with no cards, stops after the first ring', () async {
      final snapshots = await scanHistory(
        calendar: calendar,
        now: now,
        cardCodes: const {},
      ).toList();

      expect(snapshots.single.done, isTrue);
      expect(calendar.listQueries, hasLength(1));
    });

    test('without access, reads nothing and says so', () async {
      calendar.access = CalendarAccess.denied;

      final snapshots = await scanHistory(
        calendar: calendar,
        now: now,
        cardCodes: {'ab'},
      ).toList();

      expect(snapshots.single.done, isTrue);
      expect(snapshots.single.hasAccess, isFalse);
      expect(calendar.listQueries, isEmpty);
    });

    test('a failed read ends the scan with what it has', () async {
      final failing = _FailingCalendar(failAfter: 1)
        ..events.add(
          _event('e1', DateTime(2026, 9, 1, 10), notes: 'Recur - rcab001'),
        );

      final snapshots = await scanHistory(
        calendar: failing,
        now: now,
        cardCodes: {'ab'},
      ).toList();

      expect(snapshots.map((s) => s.done), [false, true]);
      expect(
        snapshots.last.historyFor('ab').lineStart,
        DateTime(2026, 9, 1, 10),
      );
    });
  });
}

/// A [FakeCalendarGateway] whose reads fail after the first [failAfter].
class _FailingCalendar extends FakeCalendarGateway {
  _FailingCalendar({required this.failAfter});

  final int failAfter;
  int _reads = 0;

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime from,
    required DateTime to,
  }) {
    if (_reads++ >= failAfter) {
      throw StateError('read failed');
    }
    return super.listEvents(from: from, to: to);
  }
}
