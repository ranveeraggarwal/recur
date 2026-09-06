/// The real [CalendarGateway], backed by `device_calendar_plus`.
///
/// This is the only file in the app that imports `device_calendar_plus`.
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

/// Maps a plugin [Calendar] to a [CalendarInfo].
CalendarInfo calendarInfoFrom(Calendar calendar) {
  return CalendarInfo(
    id: calendar.id,
    name: calendar.name,
    accountName: calendar.accountName,
    isPrimary: calendar.isPrimary,
  );
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
  Future<List<CalendarInfo>> listWritableCalendars() async {
    final calendars = await _plugin.listCalendars();
    return calendars
        .where((calendar) => !calendar.readOnly && !calendar.hidden)
        .map(calendarInfoFrom)
        .toList();
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
  Future<Set<String>> existingEventIds(Set<String> eventIds) async {
    final alive = <String>{};
    for (final id in eventIds) {
      final event = await _plugin.getEvent(id);
      if (event != null && event.status != EventStatus.canceled) {
        alive.add(id);
      }
    }
    return alive;
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
    try {
      return await _plugin.createEvent(
        calendarId: calendarId,
        title: title,
        startDate: start,
        endDate: end,
        location: location,
        description: notes,
      );
    } on DeviceCalendarException catch (e) {
      throw CalendarWriteException(e.message, e);
    } on PlatformException catch (e) {
      throw CalendarWriteException(
        e.message ?? 'Failed to create calendar event.',
        e,
      );
    }
  }
}
