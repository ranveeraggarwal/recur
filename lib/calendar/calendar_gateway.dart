/// The one door to the phone calendar.
///
/// Nothing in the app talks to the calendar plugin directly. Everything
/// goes through [CalendarGateway]. Only the file that implements this
/// interface against the real plugin knows the plugin exists; every screen
/// and every test uses `FakeCalendarGateway`. See `docs/architecture.md`,
/// section "Calendar gateway".
library;

/// Whether the app can read and write the phone calendar.
enum CalendarAccess {
  /// Read and write granted.
  granted,

  /// Not asked yet, or asked and can ask again. [CalendarGateway.requestAccess]
  /// shows the system dialog.
  notDetermined,

  /// The system dialog can no longer be shown.
  /// [CalendarGateway.openSystemSettings] is the only way out.
  denied,
}

/// A calendar the app can list or write to.
final class CalendarInfo {
  const CalendarInfo({
    required this.id,
    required this.name,
    this.accountName,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final String? accountName;
  final bool isPrimary;

  @override
  bool operator ==(Object other) =>
      other is CalendarInfo &&
      other.id == id &&
      other.name == name &&
      other.accountName == accountName &&
      other.isPrimary == isPrimary;

  @override
  int get hashCode => Object.hash(id, name, accountName, isPrimary);

  @override
  String toString() =>
      'CalendarInfo(id: $id, name: $name, accountName: $accountName, '
      'isPrimary: $isPrimary)';
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

/// Thrown when [CalendarGateway.createEvent] fails to write an event.
class CalendarWriteException implements Exception {
  CalendarWriteException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'CalendarWriteException: $message';
}

/// The boundary the app talks to instead of the calendar plugin directly.
abstract interface class CalendarGateway {
  Future<CalendarAccess> checkAccess();
  Future<CalendarAccess> requestAccess();
  Future<void> openSystemSettings();

  /// Calendars the app may write to. Read-only and hidden calendars are
  /// excluded.
  Future<List<CalendarInfo>> listWritableCalendars();

  /// Busy intervals from every readable calendar, overlapping `[from, to)`.
  /// Recurring events are expanded. All-day events and events with
  /// availability "free" are excluded. Requires `access == granted`.
  Future<List<BusyInterval>> busyIntervals({
    required DateTime from,
    required DateTime to,
  });

  /// Creates one timed, non-recurring event. Returns the calendar event id.
  /// Throws [CalendarWriteException] on failure.
  Future<String> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? notes,
  });
}
