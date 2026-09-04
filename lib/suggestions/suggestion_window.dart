/// The result of [suggestionWindowFor]: which weekdays and time-of-day span
/// a card's slots should be highlighted in. See `docs/architecture.md`,
/// section "Suggestion engine".
library;

/// A set of weekdays plus a time-of-day span. A slot is highlighted when its
/// day's weekday is in [weekdays] and the appointment fits between
/// [startMinutes] and [endMinutes].
final class SuggestionWindow {
  const SuggestionWindow({
    required this.weekdays,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// Subset of 1..7 (1 = Monday .. 7 = Sunday).
  final Set<int> weekdays;

  /// Minutes since midnight, 360..1320.
  final int startMinutes;

  /// Minutes since midnight, startMinutes..1320.
  final int endMinutes;

  @override
  bool operator ==(Object other) =>
      other is SuggestionWindow &&
      _setEquals(other.weekdays, weekdays) &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(weekdays),
    startMinutes,
    endMinutes,
  );

  @override
  String toString() =>
      'SuggestionWindow(weekdays: $weekdays, startMinutes: $startMinutes, '
      'endMinutes: $endMinutes)';
}

bool _setEquals(Set<int> a, Set<int> b) {
  if (a.length != b.length) return false;
  for (final value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}
