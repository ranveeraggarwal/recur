/// An in-memory [CalendarGateway], for every screen and every test.
///
/// See `docs/architecture.md`, section "Calendar gateway".
library;

import 'calendar_gateway.dart';

/// One call to [FakeCalendarGateway.openNewEvent], in order.
final class OpenedEvent {
  const OpenedEvent({
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.notes,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? notes;

  @override
  bool operator ==(Object other) =>
      other is OpenedEvent &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.location == location &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(title, start, end, location, notes);

  @override
  String toString() =>
      'OpenedEvent(title: $title, start: $start, end: $end, '
      'location: $location, notes: $notes)';
}

/// A plain, mutable, `const`-free [CalendarGateway] that lives in memory.
///
/// Tests poke the fields directly rather than going through a constructor:
/// set [access] or [accessAfterRequest] to steer permission behaviour, seed
/// [busy] or [events], or set [failNextOpenWith] to make the next
/// [openNewEvent] call fail. [saveOpened] stands in for the user tapping
/// save in the calendar app.
class FakeCalendarGateway implements CalendarGateway {
  /// What [checkAccess] returns, and the starting permission state.
  CalendarAccess access = CalendarAccess.granted;

  /// What [requestAccess] will return (and set [access] to).
  CalendarAccess accessAfterRequest = CalendarAccess.granted;

  int requestAccessCalls = 0;
  int openSystemSettingsCalls = 0;

  /// Busy intervals returned by [busyIntervals], in addition to one per
  /// timed entry in [events].
  final List<BusyInterval> busy = [];

  /// Every event in the calendar, returned by [listEvents].
  final List<CalendarEvent> events = [];

  /// Every `(from, to)` pair [listEvents] was called with, in order.
  final List<({DateTime from, DateTime to})> listQueries = [];

  /// Every `(from, to)` pair [busyIntervals] was called with, in order.
  final List<({DateTime from, DateTime to})> busyQueries = [];

  /// Every [openNewEvent] call that succeeded, in order.
  final List<OpenedEvent> opened = [];

  /// If set, the next [openNewEvent] call throws [CalendarOpenException]
  /// with this message and then clears back to `null`.
  String? failNextOpenWith;

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
      for (final event in events)
        if (!event.isAllDay && event.end.isAfter(event.start))
          BusyInterval(
            start: event.start,
            end: event.end,
            title: event.title.isEmpty ? null : event.title,
          ),
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
  Future<List<CalendarEvent>> listEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    if (access != CalendarAccess.granted) {
      throw StateError('listEvents requires access == granted.');
    }

    listQueries.add((from: from, to: to));

    final overlapping =
        events
            .where(
              (event) => event.start.isBefore(to) && event.end.isAfter(from),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    return overlapping;
  }

  @override
  Future<void> openNewEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? notes,
  }) async {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'Must be after start.');
    }

    if (failNextOpenWith != null) {
      final message = failNextOpenWith!;
      failNextOpenWith = null;
      throw CalendarOpenException(message);
    }

    opened.add(
      OpenedEvent(
        title: title,
        start: start,
        end: end,
        location: location,
        notes: notes,
      ),
    );
  }

  /// Adds the last opened event to [events] as if the user saved it in
  /// the calendar app, and returns it.
  CalendarEvent saveOpened() {
    final last = opened.last;
    final event = CalendarEvent(
      id: 'evt-${_nextEventNumber++}',
      calendarId: 'cal-1',
      title: last.title,
      start: last.start,
      end: last.end,
      isAllDay: false,
      location: last.location,
      notes: last.notes,
    );
    events.add(event);
    return event;
  }
}
