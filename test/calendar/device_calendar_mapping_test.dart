import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/calendar/device_calendar_gateway.dart';

Event _event({
  required String title,
  bool isAllDay = false,
  EventAvailability availability = EventAvailability.busy,
}) {
  final start = DateTime(2024, 1, 10, 9);
  final end = DateTime(2024, 1, 10, 10);
  return Event(
    eventId: 'e1',
    instanceId: 'e1',
    calendarId: 'cal-1',
    title: title,
    startDate: start,
    endDate: end,
    isAllDay: isAllDay,
    availability: availability,
    status: EventStatus.confirmed,
    isRecurring: false,
  );
}

void main() {
  group('accessFromStatus', () {
    test('granted maps to granted', () {
      expect(
        accessFromStatus(CalendarPermissionStatus.granted),
        CalendarAccess.granted,
      );
    });

    test('notDetermined maps to notDetermined', () {
      expect(
        accessFromStatus(CalendarPermissionStatus.notDetermined),
        CalendarAccess.notDetermined,
      );
    });

    test('writeOnly maps to notDetermined', () {
      expect(
        accessFromStatus(CalendarPermissionStatus.writeOnly),
        CalendarAccess.notDetermined,
      );
    });

    test('denied maps to denied', () {
      expect(
        accessFromStatus(CalendarPermissionStatus.denied),
        CalendarAccess.denied,
      );
    });

    test('restricted maps to denied', () {
      expect(
        accessFromStatus(CalendarPermissionStatus.restricted),
        CalendarAccess.denied,
      );
    });
  });

  group('calendarInfoFrom', () {
    test('maps all fields', () {
      const calendar = Calendar(
        id: 'cal-1',
        name: 'Personal',
        readOnly: false,
        accountName: 'me@example.com',
        isPrimary: true,
      );

      expect(
        calendarInfoFrom(calendar),
        const CalendarInfo(
          id: 'cal-1',
          name: 'Personal',
          accountName: 'me@example.com',
          isPrimary: true,
        ),
      );
    });

    test('maps a calendar with no account name', () {
      const calendar = Calendar(id: 'cal-2', name: 'Work', readOnly: false);

      expect(
        calendarInfoFrom(calendar),
        const CalendarInfo(
          id: 'cal-2',
          name: 'Work',
          accountName: null,
          isPrimary: false,
        ),
      );
    });
  });

  group('busyIntervalFrom', () {
    test('trims the title', () {
      final event = _event(title: '  Dentist  ');

      final interval = busyIntervalFrom(event);

      expect(interval.start, event.startDate);
      expect(interval.end, event.endDate);
      expect(interval.title, 'Dentist');
    });

    test('an empty (or whitespace-only) title becomes null', () {
      expect(busyIntervalFrom(_event(title: '')).title, isNull);
      expect(busyIntervalFrom(_event(title: '   ')).title, isNull);
    });
  });

  group('isBlockingEvent', () {
    test('false for an all-day event', () {
      expect(
        isBlockingEvent(
          _event(
            title: 'Holiday',
            isAllDay: true,
            availability: EventAvailability.busy,
          ),
        ),
        isFalse,
      );
    });

    test('false for a free event', () {
      expect(
        isBlockingEvent(
          _event(title: 'Optional', availability: EventAvailability.free),
        ),
        isFalse,
      );
    });

    test('true for a busy event', () {
      expect(
        isBlockingEvent(
          _event(title: 'Meeting', availability: EventAvailability.busy),
        ),
        isTrue,
      );
    });

    test('true for a tentative event', () {
      expect(
        isBlockingEvent(
          _event(title: 'Maybe', availability: EventAvailability.tentative),
        ),
        isTrue,
      );
    });
  });
}
