/// The result of [suggestionWindowFor]: which weekdays and which spans of
/// the day a card's slots should be highlighted in. See
/// `docs/architecture.md`, section "Suggestion engine".
library;

import '../core/time_window.dart';

/// A set of weekdays plus one or more time-of-day spans. A slot is
/// highlighted when its day's weekday is in [weekdays] and the appointment
/// fits inside any one of [windows].
final class SuggestionWindow {
  const SuggestionWindow({required this.weekdays, required this.windows});

  /// Subset of 1..7 (1 = Monday .. 7 = Sunday).
  final Set<int> weekdays;

  /// The spans of the day that suit this card. Empty means nothing is
  /// highlighted.
  final List<TimeWindow> windows;

  /// Whether an appointment on [weekday] running `[start, end)` sits
  /// inside this suggestion.
  bool highlights({
    required int weekday,
    required int start,
    required int end,
  }) =>
      weekdays.contains(weekday) &&
      windowsContain(windows, start: start, end: end);

  @override
  bool operator ==(Object other) =>
      other is SuggestionWindow &&
      _setEquals(other.weekdays, weekdays) &&
      timeWindowListEquals(other.windows, windows);

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(weekdays), Object.hashAll(windows));

  @override
  String toString() =>
      'SuggestionWindow(weekdays: $weekdays, windows: $windows)';
}

bool _setEquals(Set<int> a, Set<int> b) {
  if (a.length != b.length) return false;
  for (final value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}
