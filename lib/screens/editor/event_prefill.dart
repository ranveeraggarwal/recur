/// Turns events already in the phone calendar into draft cards, so a new
/// card can be filled in from something the user has booked before rather
/// than typed out again.
library;

import '../../calendar/calendar_gateway.dart';
import '../../core/time_of_day_minutes.dart';
import '../../core/time_window.dart';

/// The most cards the picker offers, newest first. A long calendar would
/// otherwise fill the sheet with everything the user has ever done.
const int maxPrefills = 30;

/// A card's fields, read off one title's occurrences in the calendar.
///
/// Every field is already inside the Editor's limits: the name is trimmed
/// to 40 characters, the duration is a multiple of 5 between 5 and 480,
/// and the window sits on 30-minute marks between 06:00 and 22:00 with
/// room for the duration.
final class EventPrefill {
  const EventPrefill({
    required this.name,
    required this.durationMinutes,
    this.location,
    this.notes,
    required this.weekdays,
    required this.windows,
    required this.latestStart,
    required this.occurrences,
  });

  final String name;
  final int durationMinutes;
  final String? location;
  final String? notes;

  /// The weekdays the event has actually fallen on, 1 = Monday.
  final Set<int> weekdays;

  /// One window, spanning the earliest start to the latest end seen.
  final List<TimeWindow> windows;

  /// The start of the most recent occurrence, for the picker's caption.
  final DateTime latestStart;

  /// How many occurrences this was read from.
  final int occurrences;

  @override
  String toString() =>
      'EventPrefill(name: $name, durationMinutes: $durationMinutes, '
      'occurrences: $occurrences)';
}

/// Groups [events] by title and turns each group into an [EventPrefill],
/// most recently seen first.
///
/// Events that could not be a card are dropped: all-day ones, untitled
/// ones, and anything shorter than 5 or longer than 480 minutes.
List<EventPrefill> prefillsFromEvents(List<CalendarEvent> events) {
  final byTitle = <String, List<CalendarEvent>>{};
  for (final event in events) {
    final title = event.title.trim();
    if (title.isEmpty || event.isAllDay) continue;
    final minutes = event.durationMinutes;
    if (minutes < 5 || minutes > 480) continue;
    byTitle.putIfAbsent(title, () => []).add(event);
  }

  final prefills = <EventPrefill>[];
  for (final entry in byTitle.entries) {
    final occurrences = entry.value..sort((a, b) => a.start.compareTo(b.start));
    prefills.add(_prefillFor(entry.key, occurrences));
  }

  prefills.sort((a, b) => b.latestStart.compareTo(a.latestStart));
  return prefills.take(maxPrefills).toList();
}

EventPrefill _prefillFor(String title, List<CalendarEvent> occurrences) {
  final latest = occurrences.last;
  final duration = _roundToFive(latest.durationMinutes);

  var earliest = dayEndMinutes;
  var latestEnd = dayStartMinutes;
  final weekdays = <int>{};
  for (final event in occurrences) {
    weekdays.add(event.start.weekday);
    final start = _roundDown(minutesOfDay(event.start));
    final end = _roundUp(_endMinutesOf(event));
    if (start < earliest) earliest = start;
    if (end > latestEnd) latestEnd = end;
  }

  return EventPrefill(
    name: _clip(title, 40)!,
    durationMinutes: duration,
    location: _clip(latest.location, 80),
    notes: _clip(latest.notes, 500),
    weekdays: weekdays,
    windows: [_windowFor(earliest, latestEnd, duration)],
    latestStart: latest.start,
    occurrences: occurrences.length,
  );
}

/// The event's end as minutes since its start's midnight, so an event
/// running past midnight reads as ending at 24:00 rather than wrapping.
int _endMinutesOf(CalendarEvent event) {
  final minutes = minutesOfDay(event.start) + event.durationMinutes;
  return minutes > 1440 ? 1440 : minutes;
}

/// A window covering `[earliest, latest)`, pulled inside 06:00-22:00 and
/// widened if needed so an appointment of [duration] fits.
TimeWindow _windowFor(int earliest, int latest, int duration) {
  final span = _roundUp(duration);
  var start = earliest.clamp(dayStartMinutes, dayEndMinutes - span);
  var end = latest.clamp(dayStartMinutes, dayEndMinutes);
  if (end < start + span) end = start + span;
  if (end > dayEndMinutes) {
    end = dayEndMinutes;
    start = end - span;
  }
  return TimeWindow(startMinutes: start, endMinutes: end);
}

int _roundToFive(int minutes) {
  final rounded = ((minutes / 5).round()) * 5;
  return rounded.clamp(5, 480);
}

int _roundDown(int minutes) => minutes - (minutes % slotMinutes);

int _roundUp(int minutes) {
  final remainder = minutes % slotMinutes;
  return remainder == 0 ? minutes : minutes + (slotMinutes - remainder);
}

String? _clip(String? value, int max) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.length <= max ? trimmed : trimmed.substring(0, max).trim();
}
