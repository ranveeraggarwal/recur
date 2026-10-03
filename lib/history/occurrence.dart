/// A booking as read back out of the calendar. See `docs/architecture.md`,
/// section "The data".
library;

/// One calendar event carrying a card's marker, as it is now in the
/// calendar.
final class Occurrence {
  const Occurrence({
    required this.cardCode,
    required this.occurrenceCode,
    required this.eventId,
    required this.start,
    required this.end,
  });

  final String cardCode;
  final String occurrenceCode;
  final String eventId;
  final DateTime start;
  final DateTime end;

  /// The card code and occurrence code together. Copies of one event share
  /// it.
  String get fullCode => '$cardCode$occurrenceCode';

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.cardCode == cardCode &&
      other.occurrenceCode == occurrenceCode &&
      other.eventId == eventId &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode =>
      Object.hash(cardCode, occurrenceCode, eventId, start, end);

  @override
  String toString() =>
      'Occurrence(rc$fullCode, eventId: $eventId, start: $start)';
}

/// What the calendar says about one card.
final class CardHistory {
  const CardHistory({this.past = const [], this.next});

  /// Occurrences that started before now, newest first.
  final List<Occurrence> past;

  /// The earliest occurrence that starts now or later.
  final Occurrence? next;

  /// The start the card's line describes: the next booking if there is
  /// one, else the latest past one, else `null`.
  DateTime? get lineStart =>
      next?.start ?? (past.isEmpty ? null : past.first.start);

  /// Whether further, older or later events could no longer change what
  /// the card shows: its next booking is known and three past ones are.
  bool get isSettled => next != null && past.length >= 3;
}
