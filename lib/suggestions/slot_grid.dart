/// Builds the fixed 06:00-22:00 grid of 30-minute slots for a day, marking
/// each as available, highlighted, or blocked. See `docs/architecture.md`,
/// section "Suggestion engine".
library;

import '../calendar/calendar_gateway.dart';
import '../core/local_date.dart';
import 'suggestion_window.dart';

/// Whether a [Slot] can be booked.
enum SlotState { available, highlighted, blocked }

/// Why a [Slot] is blocked. Non-null iff [Slot.state] is [SlotState.blocked].
enum BlockReason { past, conflict, outsideHours }

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

  /// Title of the first overlapping busy interval, set only when
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

const int _dayStartMinutes = 360; // 06:00
const int _dayEndMinutes = 1320; // 22:00
const int _stepMinutes = 30;

/// Builds the 32 slots for [date], each spanning [durationMinutes] starting
/// every 30 minutes from 06:00 to 21:30.
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
    var startMinutes = _dayStartMinutes;
    startMinutes < _dayEndMinutes;
    startMinutes += _stepMinutes
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

    if (endMinutes > _dayEndMinutes) {
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
    BusyInterval? blocking;
    for (final b in busy) {
      if (b.start.isBefore(slotEnd) && b.end.isAfter(slotStart)) {
        if (blocking == null || b.start.isBefore(blocking.start)) {
          blocking = b;
        }
      }
    }
    if (blocking != null) {
      slots.add(
        Slot(
          date: date,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          state: SlotState.blocked,
          blockReason: BlockReason.conflict,
          blockingTitle: blocking.title,
        ),
      );
      continue;
    }

    final highlighted =
        window.weekdays.contains(date.weekday) &&
        startMinutes >= window.startMinutes &&
        endMinutes <= window.endMinutes;
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
