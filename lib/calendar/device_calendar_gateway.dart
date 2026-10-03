/// The real [CalendarGateway], backed by `device_calendar_plus`.
///
/// This is the only file in the app that imports `device_calendar_plus`, and
/// the only one that talks to the method channel that opens the calendar
/// app.
/// Every screen and every test uses `FakeCalendarGateway` instead. See
/// `docs/architecture.md`, section "DeviceCalendarGateway (real adapter,
/// M7)".
library;

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/services.dart';

import 'calendar_gateway.dart';

/// Maps a plugin [CalendarPermissionStatus] to a [CalendarAccess].
CalendarAccess accessFromStatus(CalendarPermissionStatus status) {
  switch (status) {
    case CalendarPermissionStatus.granted:
      return CalendarAccess.granted;
    case CalendarPermissionStatus.notDetermined:
    case CalendarPermissionStatus.writeOnly:
      return CalendarAccess.notDetermined;
    case CalendarPermissionStatus.denied:
    case CalendarPermissionStatus.restricted:
      return CalendarAccess.denied;
  }
}

/// Maps a plugin [Event] to a [BusyInterval]. The title is trimmed; an
/// empty title becomes `null`.
BusyInterval busyIntervalFrom(Event event) {
  final trimmedTitle = event.title.trim();
  return BusyInterval(
    start: event.startDate,
    end: event.endDate,
    title: trimmedTitle.isEmpty ? null : trimmedTitle,
  );
}

/// Maps a plugin [Event] to a [CalendarEvent]. Titles and descriptions are
/// trimmed; an empty description becomes `null`.
CalendarEvent calendarEventFrom(Event event) {
  final trimmedNotes = event.description?.trim();
  final trimmedLocation = event.location?.trim();
  return CalendarEvent(
    id: event.instanceId,
    calendarId: event.calendarId,
    title: event.title.trim(),
    start: event.startDate,
    end: event.endDate,
    isAllDay: event.isAllDay,
    location: (trimmedLocation == null || trimmedLocation.isEmpty)
        ? null
        : trimmedLocation,
    notes: (trimmedNotes == null || trimmedNotes.isEmpty) ? null : trimmedNotes,
  );
}

/// Whether a plugin [Event] blocks a slot: not all-day, not marked free, and
/// with an end strictly after its start. Android allows `DTEND == DTSTART`
/// (a zero-length event) and some sync sources produce an end before the
/// start; neither should block anything.
bool isBlockingEvent(Event event) {
  return !event.isAllDay &&
      event.availability != EventAvailability.free &&
      event.endDate.isAfter(event.startDate);
}

/// The real [CalendarGateway], wrapping [DeviceCalendar.instance].
class DeviceCalendarGateway implements CalendarGateway {
  DeviceCalendarGateway({DeviceCalendar? plugin})
    : _plugin = plugin ?? DeviceCalendar.instance;

  final DeviceCalendar _plugin;

  /// Handled by `MainActivity.kt`, which fires `ACTION_INSERT` on the
  /// calendar's events table.
  static const _channel = MethodChannel('recur/calendar_intent');

  @override
  Future<CalendarAccess> checkAccess() async {
    return accessFromStatus(await _plugin.hasPermissions());
  }

  @override
  Future<CalendarAccess> requestAccess() async {
    return accessFromStatus(
      await _plugin.requestPermissions(level: CalendarAccessLevel.full),
    );
  }

  @override
  Future<void> openSystemSettings() async {
    await _plugin.openAppSettings();
  }

  @override
  Future<List<BusyInterval>> busyIntervals({
    required DateTime from,
    required DateTime to,
  }) async {
    final events = await _plugin.listEvents(from, to);
    final intervals =
        events.where(isBlockingEvent).map(busyIntervalFrom).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return intervals;
  }

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    final events = await _plugin.listEvents(from, to);
    final mapped = events.map(calendarEventFrom).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return mapped;
  }

  @override
  Future<void> openNewEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? notes,
  }) async {
    try {
      await _channel.invokeMethod<void>('insertEvent', {
        'title': title,
        'beginMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
        'location': location,
        'description': notes,
      });
    } on PlatformException catch (e) {
      throw CalendarOpenException(
        e.message ?? 'Failed to open the calendar app.',
        e,
      );
    } on MissingPluginException catch (e) {
      throw CalendarOpenException('Failed to open the calendar app.', e);
    }
  }
}
