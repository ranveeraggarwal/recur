/// Turns an event already in the phone calendar into a draft card, so a
/// new card can be filled in from something the user has booked before
/// rather than typed out again.
library;

import '../../calendar/calendar_gateway.dart';
import '../../core/time_of_day_minutes.dart';
import '../../core/time_window.dart';

/// A card's fields, read off one event in the calendar and the other
/// occurrences that share its name.
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
    required this.sourceStart,
    required this.occurrences,
  });

  final String name;
  final int durationMinutes;

  /// Where the event is. Taken from the tapped occurrence, or from the
  /// most recent one that has a location when the tapped one has none.
  final String? location;

  /// The event's description, under the same rule as [location].
  final String? notes;

  /// The weekdays this event has actually fallen on, 1 = Monday.
  final Set<int> weekdays;

  /// One window, spanning the earliest start to the latest end seen
  /// across every occurrence.
  final List<TimeWindow> windows;

  /// The start of the occurrence this was copied from.
  final DateTime sourceStart;

  /// How many occurrences of this name the weekdays and window were read
  /// from, the tapped one included.
  final int occurrences;

  @override
  String toString() =>
      'EventPrefill(name: $name, durationMinutes: $durationMinutes, '
      'occurrences: $occurrences)';
}

/// Whether [event] could become a card at all. All-day events, untitled
/// ones, and anything shorter than 5 or longer than 480 minutes cannot:
/// the Editor has no way to hold them.
bool canPrefillFrom(CalendarEvent event) {
  if (event.isAllDay) return false;
  if (event.title.trim().isEmpty) return false;
  final minutes = event.durationMinutes;
  return minutes >= 5 && minutes <= 480;
}

/// Builds the card [event] would become.
///
/// The tapped occurrence supplies the details — name, how long it takes,
/// where it is, its notes. Every other occurrence of the same name in
/// [allEvents] supplies the pattern: which weekdays it falls on and the
/// span of the day it runs in. A detail the tapped occurrence is missing
/// is taken from the most recent occurrence that has one, so a series
/// whose latest instance dropped its location still copies it.
///
/// Returns `null` when [event] could not be a card; see [canPrefillFrom].
EventPrefill? prefillFor({
  required CalendarEvent event,
  required List<CalendarEvent> allEvents,
}) {
  if (!canPrefillFrom(event)) return null;

  final title = event.title.trim();
  final occurrences =
      allEvents
          .where((e) => canPrefillFrom(e) && e.title.trim() == title)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  if (occurrences.isEmpty) occurrences.add(event);

  var earliest = dayEndMinutes;
  var latestEnd = dayStartMinutes;
  final weekdays = <int>{};
  for (final occurrence in occurrences) {
    weekdays.add(occurrence.start.weekday);
    final start = roundDownToSlot(minutesOfDay(occurrence.start));
    final end = roundUpToSlot(_endMinutesOf(occurrence));
    if (start < earliest) earliest = start;
    if (end > latestEnd) latestEnd = end;
  }

  final duration = _roundToFive(event.durationMinutes);

  return EventPrefill(
    name: _clip(title, 40)!,
    durationMinutes: duration,
    location: _detail(event.location, occurrences, (e) => e.location, 80),
    notes: _detail(event.notes, occurrences, (e) => e.notes, 500),
    weekdays: weekdays,
    windows: [_windowFor(earliest, latestEnd, duration)],
    sourceStart: event.start,
    occurrences: occurrences.length,
  );
}

/// [preferred] when the tapped occurrence has it, else the same field off
/// the most recent [occurrences] that does, else `null`. Android stores a
/// missing location as an empty string rather than null, so "has it"
/// means non-empty once trimmed.
String? _detail(
  String? preferred,
  List<CalendarEvent> occurrences,
  String? Function(CalendarEvent) field,
  int max,
) {
  final own = _clip(preferred, max);
  if (own != null) return own;
  for (final occurrence in occurrences.reversed) {
    final value = _clip(field(occurrence), max);
    if (value != null) return value;
  }
  return null;
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
  final span = roundUpToSlot(duration);
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

String? _clip(String? value, int max) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.length <= max ? trimmed : trimmed.substring(0, max).trim();
}
