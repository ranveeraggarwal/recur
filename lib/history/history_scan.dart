/// Rebuilds every card's history from the calendar, in widening rings
/// around today. See `docs/architecture.md`, section "The history scan".
library;

import '../calendar/calendar_gateway.dart';
import '../core/local_date.dart';
import 'marker.dart';
import 'occurrence.dart';

/// One ring's reads: two ranges, one either side of the ring before it,
/// except the first, which is a single range around today.
typedef HistoryRange = ({DateTime from, DateTime to});

/// The days either side of today each ring reaches out to.
const List<int> historyRingDays = [7, 30, 365];

/// The ranges each ring reads, innermost first. No two ranges overlap, so
/// every event is read once.
List<List<HistoryRange>> historyRings(DateTime now) {
  final today = LocalDate.fromDateTime(now);
  DateTime day(int offset) => today.addDays(offset).at(0);

  final rings = <List<HistoryRange>>[];
  var inner = 0;
  for (final outer in historyRingDays) {
    if (inner == 0) {
      rings.add([(from: day(-outer), to: day(outer))]);
    } else {
      rings.add([
        (from: day(-outer), to: day(-inner)),
        (from: day(inner), to: day(outer)),
      ]);
    }
    inner = outer;
  }
  return rings;
}

/// Adds every event in [events] that carries a marker to [byFullCode],
/// keeping the earliest event for each full code so copies count once.
void collectOccurrences(
  Map<String, Occurrence> byFullCode,
  Iterable<CalendarEvent> events,
) {
  for (final event in events) {
    final codes = parseMarker(event.notes);
    if (codes == null) continue;
    final occurrence = Occurrence(
      cardCode: codes.cardCode,
      occurrenceCode: codes.occurrenceCode,
      eventId: event.id,
      start: event.start,
      end: event.end,
    );
    final existing = byFullCode[occurrence.fullCode];
    if (existing == null || occurrence.start.isBefore(existing.start)) {
      byFullCode[occurrence.fullCode] = occurrence;
    }
  }
}

/// Groups [occurrences] by card code into a [CardHistory] each, splitting
/// past from upcoming at [now].
Map<String, CardHistory> historiesFrom(
  Iterable<Occurrence> occurrences,
  DateTime now,
) {
  final byCard = <String, List<Occurrence>>{};
  for (final occurrence in occurrences) {
    byCard.putIfAbsent(occurrence.cardCode, () => []).add(occurrence);
  }
  return {
    for (final entry in byCard.entries) entry.key: _historyOf(entry.value, now),
  };
}

CardHistory _historyOf(List<Occurrence> occurrences, DateTime now) {
  final past = <Occurrence>[];
  Occurrence? next;
  for (final occurrence in occurrences) {
    if (occurrence.start.isBefore(now)) {
      past.add(occurrence);
    } else if (next == null || occurrence.start.isBefore(next.start)) {
      next = occurrence;
    }
  }
  past.sort((a, b) => b.start.compareTo(a.start));
  return CardHistory(past: past, next: next);
}

/// Where the scan has got to.
final class HistorySnapshot {
  const HistorySnapshot({
    required this.cards,
    required this.seenCardCodes,
    required this.ringsDone,
    required this.done,
    required this.hasAccess,
  });

  /// Before any ring has been read.
  static const HistorySnapshot initial = HistorySnapshot(
    cards: {},
    seenCardCodes: {},
    ringsDone: 0,
    done: false,
    hasAccess: true,
  );

  /// By card code.
  final Map<String, CardHistory> cards;

  /// Every card code found in a marker so far, including deleted cards'.
  final Set<String> seenCardCodes;

  final int ringsDone;

  /// Whether the scan has finished, by reading every ring, by every card
  /// settling, or by failing.
  final bool done;

  /// `false` when the scan read nothing because the calendar is closed to
  /// Recur.
  final bool hasAccess;

  /// Between 0 and 1.
  double get progress => done ? 1 : ringsDone / historyRingDays.length;

  /// The history of the card with [cardCode], empty when nothing is known.
  CardHistory historyFor(String? cardCode) =>
      cards[cardCode] ?? const CardHistory();

  /// Whether what [historyFor] says about [cardCode] is final.
  bool isSettled(String? cardCode) => done || historyFor(cardCode).isSettled;
}

/// Reads the calendar ring by ring and yields a snapshot after each,
/// stopping early once every card in [cardCodes] has settled. Never throws:
/// a failed read ends the scan with what it has.
Stream<HistorySnapshot> scanHistory({
  required CalendarGateway calendar,
  required DateTime now,
  required Set<String> cardCodes,
}) async* {
  final byFullCode = <String, Occurrence>{};
  var ringsDone = 0;

  HistorySnapshot snapshot({required bool done, bool hasAccess = true}) {
    return HistorySnapshot(
      cards: historiesFrom(byFullCode.values, now),
      seenCardCodes: {for (final o in byFullCode.values) o.cardCode},
      ringsDone: ringsDone,
      done: done,
      hasAccess: hasAccess,
    );
  }

  final List<List<HistoryRange>> rings;
  try {
    if (await calendar.checkAccess() != CalendarAccess.granted) {
      yield snapshot(done: true, hasAccess: false);
      return;
    }
    rings = historyRings(now);
  } catch (_) {
    yield snapshot(done: true, hasAccess: false);
    return;
  }

  for (final ring in rings) {
    try {
      for (final range in ring) {
        collectOccurrences(
          byFullCode,
          await calendar.listEvents(from: range.from, to: range.to),
        );
      }
    } catch (_) {
      yield snapshot(done: true);
      return;
    }
    ringsDone++;
    final current = snapshot(done: false);
    final settled = cardCodes.every(current.isSettled);
    if (settled || ringsDone == rings.length) {
      yield snapshot(done: true);
      return;
    }
    yield current;
  }
}
