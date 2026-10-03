import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/calendar/fake_calendar_gateway.dart';

void main() {
  group('BusyInterval', () {
    test('value equality', () {
      final start = DateTime(2026, 9, 4, 10);
      final end = DateTime(2026, 9, 4, 11);
      final a = BusyInterval(start: start, end: end, title: 'Physio');
      final b = BusyInterval(start: start, end: end, title: 'Physio');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('asserts end is after start', () {
      final t = DateTime(2026, 9, 4, 10);
      expect(
        () => BusyInterval(start: t, end: t),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () =>
            BusyInterval(start: t, end: t.subtract(const Duration(minutes: 1))),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('OpenedEvent', () {
    test('value equality', () {
      final start = DateTime(2026, 9, 4, 10);
      final end = DateTime(2026, 9, 4, 11);
      final a = OpenedEvent(
        title: 'Physio',
        start: start,
        end: end,
        location: 'Clinic',
        notes: 'Bring towel',
      );
      final b = OpenedEvent(
        title: 'Physio',
        start: start,
        end: end,
        location: 'Clinic',
        notes: 'Bring towel',
      );
      final c = OpenedEvent(title: 'Physio', start: start, end: end);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('FakeCalendarGateway', () {
    late FakeCalendarGateway gateway;

    setUp(() {
      gateway = FakeCalendarGateway();
    });

    test('checkAccess returns access', () async {
      expect(await gateway.checkAccess(), CalendarAccess.granted);

      gateway.access = CalendarAccess.denied;
      expect(await gateway.checkAccess(), CalendarAccess.denied);
    });

    test(
      'requestAccess increments the counter, sets access, and returns it',
      () async {
        gateway.access = CalendarAccess.notDetermined;
        gateway.accessAfterRequest = CalendarAccess.granted;

        final result = await gateway.requestAccess();

        expect(result, CalendarAccess.granted);
        expect(gateway.access, CalendarAccess.granted);
        expect(gateway.requestAccessCalls, 1);

        gateway.accessAfterRequest = CalendarAccess.denied;
        final second = await gateway.requestAccess();

        expect(second, CalendarAccess.denied);
        expect(gateway.access, CalendarAccess.denied);
        expect(gateway.requestAccessCalls, 2);
      },
    );

    test('openSystemSettings increments the counter', () async {
      expect(gateway.openSystemSettingsCalls, 0);

      await gateway.openSystemSettings();
      await gateway.openSystemSettings();

      expect(gateway.openSystemSettingsCalls, 2);
    });

    group('busyIntervals', () {
      test('throws StateError unless access == granted', () {
        gateway.access = CalendarAccess.notDetermined;
        expect(
          () => gateway.busyIntervals(
            from: DateTime(2026, 9, 4),
            to: DateTime(2026, 9, 5),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError when access is denied', () {
        gateway.access = CalendarAccess.denied;
        expect(
          () => gateway.busyIntervals(
            from: DateTime(2026, 9, 4),
            to: DateTime(2026, 9, 5),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test(
        'returns entries from busy filtered by overlap, sorted by start',
        () async {
          final from = DateTime(2026, 9, 4, 9);
          final to = DateTime(2026, 9, 4, 17);

          final before = BusyInterval(
            start: DateTime(2026, 9, 4, 6),
            end: DateTime(2026, 9, 4, 7),
          );
          final overlapsStart = BusyInterval(
            start: DateTime(2026, 9, 4, 8),
            end: DateTime(2026, 9, 4, 10),
          );
          final inside = BusyInterval(
            start: DateTime(2026, 9, 4, 12),
            end: DateTime(2026, 9, 4, 13),
          );
          final overlapsEnd = BusyInterval(
            start: DateTime(2026, 9, 4, 16),
            end: DateTime(2026, 9, 4, 18),
          );
          final after = BusyInterval(
            start: DateTime(2026, 9, 4, 18),
            end: DateTime(2026, 9, 4, 19),
          );

          gateway.busy.addAll([
            after,
            inside,
            before,
            overlapsEnd,
            overlapsStart,
          ]);

          final result = await gateway.busyIntervals(from: from, to: to);

          expect(result, [overlapsStart, inside, overlapsEnd]);
        },
      );

      test('excludes an interval that ends exactly at from', () async {
        final from = DateTime(2026, 9, 4, 9);
        final to = DateTime(2026, 9, 4, 17);

        gateway.busy.add(
          BusyInterval(start: DateTime(2026, 9, 4, 8), end: from),
        );

        final result = await gateway.busyIntervals(from: from, to: to);

        expect(result, isEmpty);
      });

      test('excludes an interval that starts exactly at to', () async {
        final from = DateTime(2026, 9, 4, 9);
        final to = DateTime(2026, 9, 4, 17);

        gateway.busy.add(
          BusyInterval(start: to, end: DateTime(2026, 9, 4, 18)),
        );

        final result = await gateway.busyIntervals(from: from, to: to);

        expect(result, isEmpty);
      });

      test('includes a half-open touching interval starting at from', () async {
        final from = DateTime(2026, 9, 4, 9);
        final to = DateTime(2026, 9, 4, 17);
        final touching = BusyInterval(
          start: from,
          end: DateTime(2026, 9, 4, 10),
        );

        gateway.busy.add(touching);

        final result = await gateway.busyIntervals(from: from, to: to);

        expect(result, [touching]);
      });

      test(
        'timed events in events count as busy, all-day ones do not',
        () async {
          gateway.events.addAll([
            CalendarEvent(
              id: 'evt-1',
              calendarId: 'cal-1',
              title: 'Physio',
              start: DateTime(2026, 9, 4, 10),
              end: DateTime(2026, 9, 4, 11),
              isAllDay: false,
            ),
            CalendarEvent(
              id: 'evt-2',
              calendarId: 'cal-1',
              title: 'Holiday',
              start: DateTime(2026, 9, 4),
              end: DateTime(2026, 9, 5),
              isAllDay: true,
            ),
          ]);

          final result = await gateway.busyIntervals(
            from: DateTime(2026, 9, 4, 9),
            to: DateTime(2026, 9, 4, 17),
          );

          expect(result, [
            BusyInterval(
              start: DateTime(2026, 9, 4, 10),
              end: DateTime(2026, 9, 4, 11),
              title: 'Physio',
            ),
          ]);
        },
      );
    });

    group('openNewEvent', () {
      test('records the call and works without access', () async {
        gateway.access = CalendarAccess.denied;

        await gateway.openNewEvent(
          title: 'Physio',
          start: DateTime(2026, 9, 4, 10),
          end: DateTime(2026, 9, 4, 11),
          location: 'Clinic',
          notes: 'Booked with Recur - rcab123',
        );

        expect(gateway.opened, [
          OpenedEvent(
            title: 'Physio',
            start: DateTime(2026, 9, 4, 10),
            end: DateTime(2026, 9, 4, 11),
            location: 'Clinic',
            notes: 'Booked with Recur - rcab123',
          ),
        ]);
      });

      test('throws ArgumentError when end is not after start', () {
        final t = DateTime(2026, 9, 4, 10);
        expect(
          () => gateway.openNewEvent(title: 'Physio', start: t, end: t),
          throwsArgumentError,
        );
      });

      test('failNextOpenWith fails one call and then clears', () async {
        gateway.failNextOpenWith = 'No calendar app.';
        final start = DateTime(2026, 9, 4, 10);
        final end = DateTime(2026, 9, 4, 11);

        await expectLater(
          gateway.openNewEvent(title: 'Physio', start: start, end: end),
          throwsA(
            isA<CalendarOpenException>().having(
              (e) => e.message,
              'message',
              'No calendar app.',
            ),
          ),
        );
        expect(gateway.failNextOpenWith, isNull);
        expect(gateway.opened, isEmpty);

        await gateway.openNewEvent(title: 'Physio', start: start, end: end);
        expect(gateway.opened, hasLength(1));
      });

      test('saveOpened adds the last opened event to events', () async {
        await gateway.openNewEvent(
          title: 'Physio',
          start: DateTime(2026, 9, 4, 10),
          end: DateTime(2026, 9, 4, 11),
          notes: 'Booked with Recur - rcab123',
        );

        final saved = gateway.saveOpened();

        expect(gateway.events, [saved]);
        expect(saved.title, 'Physio');
        expect(saved.notes, 'Booked with Recur - rcab123');
      });
    });

    group('listEvents', () {
      test('returns seeded events sorted by start', () async {
        gateway.events.addAll([
          CalendarEvent(
            id: 'seed-1',
            calendarId: 'cal-1',
            title: 'Physio',
            start: DateTime(2026, 9, 4, 14),
            end: DateTime(2026, 9, 4, 15),
            isAllDay: false,
          ),
          CalendarEvent(
            id: 'seed-2',
            calendarId: 'cal-1',
            title: 'PT session',
            start: DateTime(2026, 9, 4, 10),
            end: DateTime(2026, 9, 4, 11),
            isAllDay: false,
          ),
        ]);

        final events = await gateway.listEvents(
          from: DateTime(2026, 9, 4),
          to: DateTime(2026, 9, 5),
        );

        expect(events.map((e) => e.title), ['PT session', 'Physio']);
      });

      test('excludes events outside the range', () async {
        gateway.events.add(
          CalendarEvent(
            id: 'seed-1',
            calendarId: 'cal-1',
            title: 'Physio',
            start: DateTime(2026, 9, 10, 14),
            end: DateTime(2026, 9, 10, 15),
            isAllDay: false,
          ),
        );

        final events = await gateway.listEvents(
          from: DateTime(2026, 9, 4),
          to: DateTime(2026, 9, 5),
        );

        expect(events, isEmpty);
      });

      test('throws without access', () async {
        gateway.access = CalendarAccess.denied;

        expect(
          () => gateway.listEvents(
            from: DateTime(2026, 9, 4),
            to: DateTime(2026, 9, 5),
          ),
          throwsStateError,
        );
      });
    });
  });
}
