/// Picks the one time a card is suggested at when it is tapped. See
/// `docs/architecture.md`, section "The slot logic".
library;

import '../calendar/calendar_gateway.dart';
import '../core/local_date.dart';
import '../data/models/event_type.dart';
import 'slot_grid.dart';
import 'suggestion_window.dart';

/// How many days, starting tomorrow, are searched for a free slot.
const int suggestionSearchDays = 14;

/// The range of days [firstSuggestedSlot] looks at, for reading busy times:
/// tomorrow at midnight up to midnight [suggestionSearchDays] later.
({DateTime from, DateTime to}) suggestionSearchRange(DateTime now) {
  final tomorrow = LocalDate.fromDateTime(now).addDays(1);
  return (
    from: tomorrow.at(0),
    to: tomorrow.addDays(suggestionSearchDays).at(0),
  );
}

/// The first highlighted slot from tomorrow through the next
/// [suggestionSearchDays] days. When none of those days has one, tomorrow
/// at the start of [eventType]'s first preferred window, busy or not.
///
/// Pure: depends only on its arguments.
({DateTime start, DateTime end}) firstSuggestedSlot({
  required EventType eventType,
  required SuggestionWindow window,
  required List<BusyInterval> busy,
  required DateTime now,
}) {
  final tomorrow = LocalDate.fromDateTime(now).addDays(1);
  for (var offset = 0; offset < suggestionSearchDays; offset++) {
    final date = tomorrow.addDays(offset);
    final slots = buildSlotGrid(
      date: date,
      durationMinutes: eventType.durationMinutes,
      window: window,
      busy: busy,
      now: now,
    );
    for (final slot in slots) {
      if (slot.state == SlotState.highlighted) {
        return (start: slot.start, end: date.at(slot.endMinutes));
      }
    }
  }
  final startMinutes = eventType.preferredStartMinutes;
  return (
    start: tomorrow.at(startMinutes),
    end: tomorrow.at(startMinutes + eventType.durationMinutes),
  );
}
