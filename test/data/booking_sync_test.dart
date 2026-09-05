import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/calendar/fake_calendar_gateway.dart';
import 'package:recur/data/booking_repository.dart';
import 'package:recur/data/booking_sync.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/data/models/booking.dart';

Booking _booking({
  required String id,
  String eventTypeId = 'et-1',
  required String calendarEventId,
  DateTime? start,
}) {
  final resolvedStart = start ?? DateTime(2026, 9, 4, 10, 0);
  return Booking(
    id: id,
    eventTypeId: eventTypeId,
    start: resolvedStart,
    end: resolvedStart.add(const Duration(minutes: 60)),
    calendarId: 'cal-1',
    calendarEventId: calendarEventId,
    createdAt: resolvedStart,
  );
}

/// A gateway whose [existingEventIds] always throws, standing in for a
/// calendar read that fails part way through.
class _FailingGateway extends FakeCalendarGateway {
  @override
  Future<Set<String>> existingEventIds(Set<String> eventIds) async {
    throw StateError('calendar unavailable');
  }
}

void main() {
  late InMemoryLocalStore store;
  late LocalBookingRepository bookings;
  late FakeCalendarGateway calendar;

  setUp(() {
    store = InMemoryLocalStore();
    bookings = LocalBookingRepository(store);
    calendar = FakeCalendarGateway();
  });

  test('drops the booking whose calendar event is gone', () async {
    await bookings.add(_booking(id: 'b-1', calendarEventId: 'evt-1'));
    await bookings.add(
      _booking(
        id: 'b-2',
        calendarEventId: 'evt-2',
        start: DateTime(2026, 9, 11, 10),
      ),
    );
    calendar.knownEventIds.add('evt-2');

    final pruned = await pruneVanishedBookings(
      bookings: bookings,
      calendar: calendar,
    );

    expect(pruned, {'b-1'});
    expect((await bookings.getAll()).map((b) => b.id), ['b-2']);
  });

  test('keeps every booking whose event is still there', () async {
    await bookings.add(_booking(id: 'b-1', calendarEventId: 'evt-1'));
    calendar.knownEventIds.add('evt-1');

    final pruned = await pruneVanishedBookings(
      bookings: bookings,
      calendar: calendar,
    );

    expect(pruned, isEmpty);
    expect(await bookings.getAll(), hasLength(1));
  });

  test('keeps everything when the calendar cannot be read', () async {
    await bookings.add(_booking(id: 'b-1', calendarEventId: 'evt-1'));
    calendar.access = CalendarAccess.denied;

    final pruned = await pruneVanishedBookings(
      bookings: bookings,
      calendar: calendar,
    );

    expect(pruned, isEmpty);
    expect(await bookings.getAll(), hasLength(1));
  });

  test('keeps everything when the lookup throws', () async {
    await bookings.add(_booking(id: 'b-1', calendarEventId: 'evt-1'));

    final pruned = await pruneVanishedBookings(
      bookings: bookings,
      calendar: _FailingGateway(),
    );

    expect(pruned, isEmpty);
    expect(await bookings.getAll(), hasLength(1));
  });

  test('checks only each card\'s most recent bookings', () async {
    for (var i = 0; i < recentBookingsChecked + 2; i++) {
      await bookings.add(
        _booking(
          id: 'b-$i',
          calendarEventId: 'evt-$i',
          start: DateTime(2026, 9, 1).add(Duration(days: i)),
        ),
      );
    }

    final pruned = await pruneVanishedBookings(
      bookings: bookings,
      calendar: calendar,
    );

    // None of the ids exist, so every checked booking goes; the two
    // oldest are never looked at.
    expect(pruned, hasLength(recentBookingsChecked));
    expect((await bookings.getAll()).map((b) => b.id), ['b-1', 'b-0']);
  });

  test('counts the most recent bookings per card, not overall', () async {
    for (var i = 0; i < recentBookingsChecked; i++) {
      await bookings.add(
        _booking(
          id: 'a-$i',
          eventTypeId: 'et-1',
          calendarEventId: 'evt-a-$i',
          start: DateTime(2026, 9, 20).add(Duration(days: i)),
        ),
      );
    }
    await bookings.add(
      _booking(
        id: 'b-1',
        eventTypeId: 'et-2',
        calendarEventId: 'evt-b-1',
        start: DateTime(2026, 9, 1),
      ),
    );

    final pruned = await pruneVanishedBookings(
      bookings: bookings,
      calendar: calendar,
    );

    expect(pruned, contains('b-1'));
  });

  test('does nothing when there are no bookings', () async {
    final pruned = await pruneVanishedBookings(
      bookings: bookings,
      calendar: calendar,
    );

    expect(pruned, isEmpty);
    expect(store.snapshot, isEmpty);
  });
}
