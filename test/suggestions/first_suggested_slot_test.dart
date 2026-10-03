import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/suggestions/first_suggested_slot.dart';
import 'package:recur/suggestions/suggestion_window.dart';

EventType _card({Set<int> weekdays = const {1, 2, 3, 4, 5}}) {
  return EventType(
    id: 'et-1',
    name: 'PT session',
    durationMinutes: 60,
    preferredWeekdays: weekdays,
    preferredWindows: [TimeWindow(startMinutes: 600, endMinutes: 720)],
    createdAt: DateTime(2026, 1, 1),
  );
}

SuggestionWindow _windowOf(EventType card) => SuggestionWindow(
  weekdays: card.preferredWeekdays,
  windows: card.preferredWindows,
);

void main() {
  // Monday, before the window opens: today would fit, but never counts.
  final now = DateTime(2026, 9, 7, 8);

  test('the search range is tomorrow plus 14 days', () {
    expect(suggestionSearchRange(now), (
      from: DateTime(2026, 9, 8),
      to: DateTime(2026, 9, 22),
    ));
  });

  test('starts tomorrow, never today', () {
    final card = _card();
    final slot = firstSuggestedSlot(
      eventType: card,
      window: _windowOf(card),
      busy: const [],
      now: now,
    );

    expect(slot.start, DateTime(2026, 9, 8, 10));
    expect(slot.end, DateTime(2026, 9, 8, 11));
  });

  test('skips busy time and days outside the window', () {
    final card = _card(weekdays: const {3});
    final slot = firstSuggestedSlot(
      eventType: card,
      window: _windowOf(card),
      busy: [
        BusyInterval(
          start: DateTime(2026, 9, 9, 10),
          end: DateTime(2026, 9, 9, 11),
        ),
      ],
      now: now,
    );

    expect(slot.start, DateTime(2026, 9, 9, 11));
  });

  test('falls back to tomorrow at the first window when nothing fits', () {
    final card = _card();
    final slot = firstSuggestedSlot(
      eventType: card,
      window: _windowOf(card),
      busy: [
        BusyInterval(start: DateTime(2026, 9, 8), end: DateTime(2026, 9, 23)),
      ],
      now: now,
    );

    expect(slot.start, DateTime(2026, 9, 8, 10));
    expect(slot.end, DateTime(2026, 9, 8, 11));
  });
}
