import 'package:flutter/material.dart';

import '../../core/time_of_day_minutes.dart';
import '../../suggestions/slot_grid.dart';
import '../../theme/tokens.dart';
import '../../widgets/slot_tile.dart';

/// The vertical 06:00-22:00 list of 30-minute [SlotTile] rows for one day.
///
/// Takes plain values only, so it does not depend on the controller.
class Timeline extends StatelessWidget {
  const Timeline({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onToggle,
    this.scrollController,
  });

  final List<Slot> slots;
  final Slot? selectedSlot;
  final ValueChanged<Slot> onToggle;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: slots.length,
      itemBuilder: (context, index) => _row(slots[index]),
    );
  }

  Widget _row(Slot slot) {
    final isHourMark = slot.startMinutes % 60 == 0;
    final coveringSelection = _coveringSelection(slot, selectedSlot);
    final appearance = coveringSelection != null
        ? SlotTileAppearance.selected
        : switch (slot.state) {
            SlotState.available => SlotTileAppearance.available,
            SlotState.highlighted => SlotTileAppearance.highlighted,
            SlotState.blocked => SlotTileAppearance.blocked,
          };
    final reasonText = slot.state == SlotState.blocked
        ? switch (slot.blockReason!) {
            BlockReason.past => 'Past',
            BlockReason.outsideHours => 'Outside hours',
            BlockReason.conflict => slot.blockingTitle ?? 'Busy',
          }
        : null;

    return SizedBox(
      height: RecurSizes.slotRow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: RecurSizes.hourGutter,
            height: RecurSizes.slotRow,
            child: Stack(
              children: [
                if (isHourMark)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: RecurColors.divider),
                        ),
                      ),
                      child: SizedBox(height: 1),
                    ),
                  ),
                if (isHourMark)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: RecurSpacing.xs,
                      left: RecurSpacing.sm,
                    ),
                    child: Text(
                      formatMinutes(slot.startMinutes),
                      style: RecurText.caption.copyWith(
                        color: RecurColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: RecurSpacing.lg),
              child: SlotTile(
                timeLabel: formatMinutes(slot.startMinutes),
                appearance: appearance,
                reasonText: reasonText,
                onTap: appearance == SlotTileAppearance.blocked
                    ? null
                    : () => onToggle(coveringSelection ?? slot),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns [selected] when [slot] falls inside its
/// `[startMinutes, endMinutes)` span (so the whole booked duration is
/// highlighted, not just the row it was picked on), else `null`.
Slot? _coveringSelection(Slot slot, Slot? selected) {
  if (selected == null || selected.date != slot.date) return null;
  if (slot.startMinutes < selected.startMinutes) return null;
  if (slot.startMinutes >= selected.endMinutes) return null;
  return selected;
}
