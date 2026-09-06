import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/local_date.dart';
import '../../suggestions/slot_grid.dart';
import '../../theme/tokens.dart';
import '../../widgets/day_pill.dart';

/// The seven-day row of [DayPill]s for the week starting [weekMonday].
///
/// Takes plain values only: [grids] supplies each day's slots so this
/// widget can derive `hasSuggestions` without depending on the controller.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.weekMonday,
    required this.selectedDate,
    required this.today,
    required this.grids,
    required this.onSelect,
  });

  final LocalDate weekMonday;
  final LocalDate selectedDate;
  final LocalDate today;
  final Map<LocalDate, List<Slot>> grids;
  final ValueChanged<LocalDate> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (var i = 0; i < 7; i++) _pillFor(i)],
      ),
    );
  }

  Widget _pillFor(int i) {
    final date = weekMonday.addDays(i);
    final slots = grids[date] ?? const [];
    final hasSuggestions = slots.any((s) => s.state == SlotState.highlighted);

    return DayPill(
      weekdayLabel: weekdayAbbrev[i],
      dayNumber: date.day,
      selected: date == selectedDate,
      enabled: date.compareTo(today) >= 0,
      hasSuggestions: hasSuggestions,
      isToday: date == today,
      onTap: () => onSelect(date),
    );
  }
}
