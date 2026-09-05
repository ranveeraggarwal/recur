import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/local_date.dart';
import 'package:recur/screens/booking/timeline.dart';
import 'package:recur/suggestions/slot_grid.dart';
import 'package:recur/widgets/slot_tile.dart';

Slot _slot(int startMinutes, {int durationMinutes = 30}) {
  return Slot(
    date: LocalDate(2026, 9, 8),
    startMinutes: startMinutes,
    endMinutes: startMinutes + durationMinutes,
    state: SlotState.available,
  );
}

void main() {
  testWidgets('a 60-minute selection highlights both rows it spans', (
    tester,
  ) async {
    final slots = [
      for (var m = 540; m < 660; m += 30) _slot(m, durationMinutes: 60),
    ];
    final selected = slots.first; // 09:00-10:00

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Timeline(
            slots: slots,
            selectedSlot: selected,
            onToggle: (_) {},
          ),
        ),
      ),
    );

    SlotTileAppearance appearanceFor(String label) => tester
        .widget<SlotTile>(
          find.byWidgetPredicate((w) => w is SlotTile && w.timeLabel == label),
        )
        .appearance;

    expect(appearanceFor('09:00'), SlotTileAppearance.selected);
    expect(appearanceFor('09:30'), SlotTileAppearance.selected);
    expect(appearanceFor('10:00'), SlotTileAppearance.available);
  });

  testWidgets('tapping a row covered by the selection toggles the original '
      'slot, not the row tapped on', (tester) async {
    final slots = [
      for (var m = 540; m < 660; m += 30) _slot(m, durationMinutes: 60),
    ];
    final selected = slots.first; // 09:00-10:00
    Slot? toggled;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Timeline(
            slots: slots,
            selectedSlot: selected,
            onToggle: (s) => toggled = s,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byWidgetPredicate((w) => w is SlotTile && w.timeLabel == '09:30'),
    );

    expect(toggled, same(selected));
  });
}
