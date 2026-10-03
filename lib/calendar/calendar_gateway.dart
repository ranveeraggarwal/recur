/// The one door to the phone calendar.
///
/// Nothing in the app talks to the calendar plugin directly. Everything
/// goes through [CalendarGateway]. Only the file that implements this
/// interface against the real plugin knows the plugin exists; every screen
/// and every test uses `FakeCalendarGateway`. See `docs/architecture.md`,
/// section "Calendar gateway".
library;

/// Whether the app can read the phone calendar.
enum CalendarAccess {
  /// Read granted.
  granted,

  /// Not asked yet, or asked and can ask again. [CalendarGateway.requestAccess]
  /// shows the system dialog.
  notDetermined,

  /// The system dialog can no longer be shown.
  /// [CalendarGateway.openSystemSettings] is the only way out.
  denied,
}

/// A half-open interval `[start, end)` in local time that blocks slots.
final class BusyInterval {
  BusyInterval({required this.start, required this.end, this.title})
    : assert(end.isAfter(start));

  final DateTime start;
  final DateTime end;

  /// `null` means the UI shows "Busy".
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is BusyInterval &&
      other.start == start &&
      other.end == end &&
      other.title == title;

  @override
  int get hashCode => Object.hash(start, end, title);

  @override
  String toString() => 'BusyInterval(start: $start, end: $end, title: $title)';
}

/// One event read back from the phone calendar, with the details a card
/// can be prefilled from. Recurring events arrive one [CalendarEvent] per
/// occurrence.
final class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    this.location,
    this.notes,
  });

  /// Identifies this occurrence.
  final String id;

  final String calendarId;

  /// Trimmed. May be empty when the event has no title.
  final String title;

  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final String? location;

  /// The event's description, trimmed; `null` when it has none.
  final String? notes;

  /// The event's length in minutes. Zero or negative for a malformed event.
  int get durationMinutes => end.difference(start).inMinutes;

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.calendarId == calendarId &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.isAllDay == isAllDay &&
      other.location == location &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(id, calendarId, title, start, end, isAllDay, location, notes);

  @override
  String toString() =>
      'CalendarEvent(id: $id, title: $title, start: $start, end: $end)';
}

/// Thrown when [CalendarGateway.openNewEvent] cannot open the calendar
/// app, usually because the phone has none that takes the intent.
class CalendarOpenException implements Exception {
  CalendarOpenException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'CalendarOpenException: $message';
}

/// The boundary the app talks to instead of the calendar plugin directly.
abstract interface class CalendarGateway {
  Future<CalendarAccess> checkAccess();
  Future<CalendarAccess> requestAccess();
  Future<void> openSystemSettings();

  /// Busy intervals from every readable calendar, overlapping `[from, to)`.
  /// Recurring events are expanded. All-day events and events with
  /// availability "free" are excluded. Requires `access == granted`.
  Future<List<BusyInterval>> busyIntervals({
    required DateTime from,
    required DateTime to,
  });

  /// Every event from every readable calendar overlapping `[from, to)`,
  /// sorted by start. Recurring events are expanded into one entry per
  /// occurrence. Unlike [busyIntervals] nothing is filtered out, so
  /// all-day and free events are included and the caller decides.
  /// Requires `access == granted`.
  Future<List<CalendarEvent>> listEvents({
    required DateTime from,
    required DateTime to,
  });

  /// Opens the calendar app on a new event filled in with these details,
  /// for the user to change and save there. Returns once the app has been
  /// launched; nothing comes back about whether the user saved. Needs no
  /// calendar access. Throws [CalendarOpenException] when no app takes it.
  Future<void> openNewEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? notes,
  });
}
