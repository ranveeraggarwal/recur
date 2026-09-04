/// Computes the [SuggestionWindow] a card's slots should be highlighted in.
/// See `docs/architecture.md`, section "Suggestion engine".
library;

import '../core/local_date.dart';
import '../core/time_of_day_minutes.dart';
import '../data/models/booking.dart';
import '../data/models/event_type.dart';
import 'suggestion_window.dart';

/// Builds the [SuggestionWindow] for [eventType] given its [bookings], as of
/// [now]. [bookings] may be in any order and may include future bookings;
/// this filters to bookings with `start` before [now].
///
/// With fewer than 3 past bookings, returns [eventType]'s stated preference
/// unchanged. Otherwise the window is derived from the 3 most recent past
/// bookings: the weekdays tied for the most common count among the three,
/// and the time span from the earliest start-of-day minute to the latest
/// end-of-day minute among them, padded by 30 minutes each side and clamped
/// to 06:00-22:00. That window is kept even if it ends up smaller than
/// [eventType]'s duration.
SuggestionWindow suggestionWindowFor({
  required EventType eventType,
  required List<Booking> bookings,
  required DateTime now,
}) {
  final past = bookings.where((b) => b.start.isBefore(now)).toList()
    ..sort((a, b) => b.start.compareTo(a.start));

  if (past.length < 3) {
    return SuggestionWindow(
      weekdays: eventType.preferredWeekdays,
      startMinutes: eventType.preferredStartMinutes,
      endMinutes: eventType.preferredEndMinutes,
    );
  }

  final recent = past.take(3).toList();

  final weekdayCounts = <int, int>{};
  for (final b in recent) {
    final weekday = b.start.weekday;
    weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
  }
  final maxCount = weekdayCounts.values.reduce((a, b) => a > b ? a : b);
  final weekdays = {
    for (final entry in weekdayCounts.entries)
      if (entry.value == maxCount) entry.key,
  };

  var earliest = 1440;
  var latest = 0;
  for (final b in recent) {
    final startMinute = minutesOfDay(b.start);
    if (startMinute < earliest) earliest = startMinute;

    final crossedMidnight =
        LocalDate.fromDateTime(b.end)
            .compareTo(LocalDate.fromDateTime(b.start)) >
        0;
    final endMinute = crossedMidnight ? 1440 : minutesOfDay(b.end);
    if (endMinute > latest) latest = endMinute;
  }

  final startMinutes = (earliest - 30) < dayStartMinutes
      ? dayStartMinutes
      : (earliest - 30);
  final endMinutes = (latest + 30) > dayEndMinutes
      ? dayEndMinutes
      : (latest + 30);

  return SuggestionWindow(
    weekdays: weekdays,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );
}
