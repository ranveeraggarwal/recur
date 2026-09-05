import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/calendar/fake_calendar_gateway.dart';

void main() {
  group('CalendarInfo', () {
    test('value equality', () {
      const a = CalendarInfo(
        id: 'cal-1',
        name: 'Personal',
        accountName: 'me@example.com',
        isPrimary: true,
      );
      const b = CalendarInfo(
        id: 'cal-1',
        name: 'Personal',
        accountName: 'me@example.com',
        isPrimary: true,
      );
      const c = CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

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

  group('CreatedEvent', () {
    test('value equality', () {
      final start = DateTime(2026, 9, 4, 10);
      final end = DateTime(2026, 9, 4, 11);
      final a = CreatedEvent(
        id: 'evt-1',
        calendarId: 'cal-1',
        title: 'Physio',
        start: start,
        end: end,
        location: 'Clinic',
        notes: 'Bring towel',
      );
      final b = CreatedEvent(
        id: 'evt-1',
        calendarId: 'cal-1',
        title: 'Physio',
        start: start,
        end: end,
        location: 'Clinic',
        notes: 'Bring towel',
      );
      final c = CreatedEvent(
        id: 'evt-2',
        calendarId: 'cal-1',
        title: 'Physio',
        start: start,
        end: end,
      );

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

    test('listWritableCalendars returns a copy of calendars', () async {
      final defaults = await gateway.listWritableCalendars();
      expect(defaults, [
        const CalendarInfo(
          id: 'cal-1',
          name: 'Personal',
          accountName: 'me@example.com',
          isPrimary: true,
        ),
      ]);

      gateway.calendars = [
        const CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false),
      ];
      final result = await gateway.listWritableCalendars();

      expect(result, gateway.calendars);
      expect(identical(result, gateway.calendars), isFalse);

      // Mutating the returned list must not affect the gateway's field.
      result.clear();
      expect(gateway.calendars, hasLength(1));
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

      test('a created event shows up in the next busyIntervals call', () async {
        final start = DateTime(2026, 9, 4, 10);
        final end = DateTime(2026, 9, 4, 11);

        await gateway.createEvent(
          calendarId: 'cal-1',
          title: 'Physio',
          start: start,
          end: end,
        );

        final result = await gateway.busyIntervals(
          from: DateTime(2026, 9, 4, 9),
          to: DateTime(2026, 9, 4, 17),
        );

        expect(result, [BusyInterval(start: start, end: end, title: 'Physio')]);
      });
    });

    group('createEvent', () {
      test('throws StateError unless access == granted', () {
        gateway.access = CalendarAccess.notDetermined;
        expect(
          () => gateway.createEvent(
            calendarId: 'cal-1',
            title: 'Physio',
            start: DateTime(2026, 9, 4, 10),
            end: DateTime(2026, 9, 4, 11),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws ArgumentError when end is not after start', () {
        final t = DateTime(2026, 9, 4, 10);
        expect(
          () => gateway.createEvent(
            calendarId: 'cal-1',
            title: 'Physio',
            start: t,
            end: t,
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => gateway.createEvent(
            calendarId: 'cal-1',
            title: 'Physio',
            start: t,
            end: t.subtract(const Duration(minutes: 1)),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when title is empty', () {
        expect(
          () => gateway.createEvent(
            calendarId: 'cal-1',
            title: '',
            start: DateTime(2026, 9, 4, 10),
            end: DateTime(2026, 9, 4, 11),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'appends a CreatedEvent with incrementing ids and returns it',
        () async {
          final start1 = DateTime(2026, 9, 4, 10);
          final end1 = DateTime(2026, 9, 4, 11);
          final id1 = await gateway.createEvent(
            calendarId: 'cal-1',
            title: 'Physio',
            start: start1,
            end: end1,
            location: 'Clinic',
            notes: 'Bring towel',
          );

          expect(id1, 'evt-1');
          expect(gateway.created, [
            CreatedEvent(
              id: 'evt-1',
              calendarId: 'cal-1',
              title: 'Physio',
              start: start1,
              end: end1,
              location: 'Clinic',
              notes: 'Bring towel',
            ),
          ]);

          final start2 = DateTime(2026, 9, 5, 10);
          final end2 = DateTime(2026, 9, 5, 11);
          final id2 = await gateway.createEvent(
            calendarId: 'cal-1',
            title: 'Trainer',
            start: start2,
            end: end2,
          );

          expect(id2, 'evt-2');
          expect(gateway.created, hasLength(2));
        },
      );

      test(
        'failNextCreateWith fires once with the message, then clears',
        () async {
          gateway.failNextCreateWith = 'no calendar access';

          await expectLater(
            gateway.createEvent(
              calendarId: 'cal-1',
              title: 'Physio',
              start: DateTime(2026, 9, 4, 10),
              end: DateTime(2026, 9, 4, 11),
            ),
            throwsA(
              isA<CalendarWriteException>().having(
                (e) => e.message,
                'message',
                'no calendar access',
              ),
            ),
          );

          expect(gateway.failNextCreateWith, isNull);
          expect(gateway.created, isEmpty);

          // The next call succeeds normally.
          final id = await gateway.createEvent(
            calendarId: 'cal-1',
            title: 'Physio',
            start: DateTime(2026, 9, 4, 10),
            end: DateTime(2026, 9, 4, 11),
          );

          expect(id, 'evt-1');
          expect(gateway.created, hasLength(1));
        },
      );
    });

    group('listEvents', () {
      test('returns seeded events and created ones, sorted by start', () async {
        gateway.events.add(
          CalendarEvent(
            id: 'seed-1',
            calendarId: 'cal-1',
            title: 'Physio',
            start: DateTime(2026, 9, 4, 14),
            end: DateTime(2026, 9, 4, 15),
            isAllDay: false,
          ),
        );
        await gateway.createEvent(
          calendarId: 'cal-1',
          title: 'PT session',
          start: DateTime(2026, 9, 4, 10),
          end: DateTime(2026, 9, 4, 11),
        );

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

    group('existingEventIds', () {
      test('keeps created ids and drops unknown ones', () async {
        final id = await gateway.createEvent(
          calendarId: 'cal-1',
          title: 'PT session',
          start: DateTime(2026, 9, 4, 10),
          end: DateTime(2026, 9, 4, 11),
        );

        expect(await gateway.existingEventIds({id, 'gone'}), {id});
      });

      test('keeps ids seeded through knownEventIds', () async {
        gateway.knownEventIds.add('evt-seeded');

        expect(await gateway.existingEventIds({'evt-seeded', 'gone'}), {
          'evt-seeded',
        });
      });

      test('throws without access', () async {
        gateway.access = CalendarAccess.denied;

        expect(() => gateway.existingEventIds({'evt-1'}), throwsStateError);
      });
    });
  });
}
