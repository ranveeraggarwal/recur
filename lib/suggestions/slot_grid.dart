/// Builds the fixed 06:00-22:00 grid of 30-minute slots for a day, marking
/// each as available, highlighted, or blocked. See `docs/architecture.md`,
/// section "Suggestion engine".
library;

import '../calendar/calendar_gateway.dart';
import '../core/local_date.dart';
import '../core/time_of_day_minutes.dart';
import 'suggestion_window.dart';

/// Whether a [Slot] can be booked.
enum SlotState { available, highlighted, blocked }

/// Why a [Slot] is blocked. Non-null iff [Slot.state] is [SlotState.blocked].
///
/// [conflict] means the slot's own 30 minutes are taken by a calendar
/// event, so a busy hour covers exactly the two rows it sits on.
/// [doesNotFit] means the row itself is free but the appointment started
/// there would run into a later event.
enum BlockReason { past, conflict, outsideHours, doesNotFit }

/// One 30-minute step in the day's slot grid, spanning
/// `[startMinutes, startMinutes + durationMinutes)`.
final class Slot {
  const Slot({
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.state,
    this.blockReason,
    this.blockingTitle,
  });

  final LocalDate date;

  /// Minutes since midnight the slot starts at: 360, 390, ... 1290.
  final int startMinutes;

  /// Minutes since midnight the appointment would end at. May exceed 1320
  /// only when the slot is blocked for [BlockReason.outsideHours].
  final int endMinutes;

  final SlotState state;

  /// Non-null iff [state] is [SlotState.blocked].
  final BlockReason? blockReason;

  /// Title of the busy interval covering this row, set only when
  /// [blockReason] is [BlockReason.conflict].
  final String? blockingTitle;

  /// Local wall-clock start of this slot.
  DateTime get start => date.at(startMinutes);

  @override
  String toString() =>
      'Slot(date: $date, startMinutes: $startMinutes, '
      'endMinutes: $endMinutes, state: $state, blockReason: $blockReason, '
      'blockingTitle: $blockingTitle)';
}

/// Builds the 32 slots for [date], each spanning [durationMinutes] starting
/// every 30 minutes from 06:00 to 21:30.
///
/// A slot is blocked when it is past, when the appointment would run past
/// 22:00, or when the appointment overlaps a busy interval. An overlapping
/// slot is a [BlockReason.conflict] when the row's own 30 minutes are
/// covered by an event (and then it names that event), and a
/// [BlockReason.doesNotFit] when they are not.
///
/// Pure: depends only on its arguments, never on [DateTime.now].
List<Slot> buildSlotGrid({
  required LocalDate date,
  required int durationMinutes,
  required SuggestionWindow window,
  required List<BusyInterval> busy,
  required DateTime now,
}) {
  final slots = <Slot>[];
  for (
    var startMinutes = dayStartMinutes;
    startMinutes < dayEndMinutes;
    startMinutes += slotMinutes
  ) {
    final endMinutes = startMinutes + durationMinutes;
    final slotStart = date.at(startMinutes);

    if (!slotStart.isAfter(now)) {
      slots.add(
        Slot(
          date: date,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          state: SlotState.blocked,
          blockReason: BlockReason.past,
        ),
      );
      continue;
    }

    if (endMinutes > dayEndMinutes) {
      slots.add(
        Slot(
          date: date,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          state: SlotState.blocked,
          blockReason: BlockReason.outsideHours,
        ),
      );
      continue;
    }

    final slotEnd = date.at(endMinutes);
    final rowEnd = date.at(startMinutes + slotMinutes);

    // The earliest event the appointment would overlap, and the earliest
    // event covering this row's own 30 minutes. They differ when the
    // appointment runs past the row into a later event: then the row
    // itself is free and the slot only fails to fit.
    BusyInterval? overlapping;
    BusyInterval? covering;
    for (final b in busy) {
      if (!b.start.isBefore(slotEnd) || !b.end.isAfter(slotStart)) continue;
      if (overlapping == null || b.start.isBefore(overlapping.start)) {
        overlapping = b;
      }
      if (b.start.isBefore(rowEnd) &&
          (covering == null || b.start.isBefore(covering.start))) {
        covering = b;
      }
    }

    if (overlapping != null) {
      slots.add(
        Slot(
          date: date,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          state: SlotState.blocked,
          blockReason: covering != null
              ? BlockReason.conflict
              : BlockReason.doesNotFit,
          blockingTitle: covering?.title,
        ),
      );
      continue;
    }

    final highlighted = window.highlights(
      weekday: date.weekday,
      start: startMinutes,
      end: endMinutes,
    );
    slots.add(
      Slot(
        date: date,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        state: highlighted ? SlotState.highlighted : SlotState.available,
      ),
    );
  }
  return slots;
}
