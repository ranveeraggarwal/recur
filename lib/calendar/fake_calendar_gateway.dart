/// An in-memory [CalendarGateway], for every screen and every test.
///
/// See `docs/architecture.md`, section "Calendar gateway".
library;

import 'calendar_gateway.dart';

/// One event created via [FakeCalendarGateway.createEvent], in order.
final class CreatedEvent {
  const CreatedEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.notes,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? notes;

  @override
  bool operator ==(Object other) =>
      other is CreatedEvent &&
      other.id == id &&
      other.calendarId == calendarId &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.location == location &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(id, calendarId, title, start, end, location, notes);

  @override
  String toString() =>
      'CreatedEvent(id: $id, calendarId: $calendarId, title: $title, '
      'start: $start, end: $end, location: $location, notes: $notes)';
}

/// A plain, mutable, `const`-free [CalendarGateway] that lives in memory.
///
/// Tests poke the fields directly rather than going through a constructor:
/// set [access] or [accessAfterRequest] to steer permission behaviour, seed
/// [calendars] or [busy], or set [failNextCreateWith] to make the next
/// [createEvent] call fail.
class FakeCalendarGateway implements CalendarGateway {
  /// What [checkAccess] returns, and the starting permission state.
  CalendarAccess access = CalendarAccess.granted;

  /// What [requestAccess] will return (and set [access] to).
  CalendarAccess accessAfterRequest = CalendarAccess.granted;

  int requestAccessCalls = 0;
  int openSystemSettingsCalls = 0;

  List<CalendarInfo> calendars = [
    const CalendarInfo(
      id: 'cal-1',
      name: 'Personal',
      accountName: 'me@example.com',
      isPrimary: true,
    ),
  ];

  /// Busy intervals returned by [busyIntervals], in addition to one per
  /// entry in [created].
  final List<BusyInterval> busy = [];

  /// Every `(from, to)` pair [busyIntervals] was called with, in order.
  final List<({DateTime from, DateTime to})> busyQueries = [];

  /// Every [createEvent] call that succeeded, in order.
  final List<CreatedEvent> created = [];

  /// If set, the next [createEvent] call throws [CalendarWriteException]
  /// with this message and then clears back to `null`.
  String? failNextCreateWith;

  int _nextEventNumber = 1;

  @override
  Future<CalendarAccess> checkAccess() async => access;

  @override
  Future<CalendarAccess> requestAccess() async {
    requestAccessCalls++;
    access = accessAfterRequest;
    return access;
  }

  @override
  Future<void> openSystemSettings() async {
    openSystemSettingsCalls++;
  }

  @override
  Future<List<CalendarInfo>> listWritableCalendars() async {
    return List.of(calendars);
  }

  @override
  Future<List<BusyInterval>> busyIntervals({
    required DateTime from,
    required DateTime to,
  }) async {
    if (access != CalendarAccess.granted) {
      throw StateError('busyIntervals requires access == granted.');
    }

    busyQueries.add((from: from, to: to));

    final all = [
      ...busy,
      for (final event in created)
        BusyInterval(start: event.start, end: event.end, title: event.title),
    ];

    final overlapping =
        all
            .where(
              (interval) =>
                  interval.start.isBefore(to) && interval.end.isAfter(from),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    return overlapping;
  }

  @override
  Future<String> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? notes,
  }) async {
    if (access != CalendarAccess.granted) {
      throw StateError('createEvent requires access == granted.');
    }
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'Must be after start.');
    }
    if (title.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty.');
    }

    if (failNextCreateWith != null) {
      final message = failNextCreateWith!;
      failNextCreateWith = null;
      throw CalendarWriteException(message);
    }

    final id = 'evt-${_nextEventNumber++}';
    created.add(
      CreatedEvent(
        id: id,
        calendarId: calendarId,
        title: title,
        start: start,
        end: end,
        location: location,
        notes: notes,
      ),
    );
    return id;
  }
}
