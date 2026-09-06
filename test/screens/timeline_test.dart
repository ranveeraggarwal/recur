import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/local_date.dart';
import 'package:recur/screens/booking/timeline.dart';
import 'package:recur/suggestions/slot_grid.dart';
import 'package:recur/theme/tokens.dart';
import 'package:recur/widgets/slot_tile.dart';

Slot _slot(
  int startMinutes, {
  int durationMinutes = 30,
  SlotState state = SlotState.available,
  BlockReason? blockReason,
  String? blockingTitle,
}) {
  return Slot(
    date: LocalDate(2026, 9, 8),
    startMinutes: startMinutes,
    endMinutes: startMinutes + durationMinutes,
    state: state,
    blockReason: blockReason,
    blockingTitle: blockingTitle,
  );
}

void main() {
  group('initialTimelineOffset', () {
    test('opens on the day\'s first highlighted slot', () {
      final slots = [
        for (var m = 360; m < 1320; m += 30)
          _slot(
            m,
            state: m == 600 || m == 630
                ? SlotState.highlighted
                : SlotState.available,
          ),
      ];

      // 10:00 is the ninth row: (600 - 360) / 30 = 8.
      expect(initialTimelineOffset(slots), 8 * RecurSizes.slotRow);
    });

    test('falls back to the 08:00 row when nothing is highlighted', () {
      final slots = [for (var m = 360; m < 1320; m += 30) _slot(m)];

      expect(initialTimelineOffset(slots), 4 * RecurSizes.slotRow);
    });

    test('falls back to the top when there is no 08:00 row', () {
      final slots = [_slot(540), _slot(570)];

      expect(initialTimelineOffset(slots), 0);
    });

    test('an empty day opens at the top', () {
      expect(initialTimelineOffset(const []), 0);
    });
  });

  testWidgets('every row is exactly one slot row tall', (tester) async {
    final slots = [for (var m = 360; m < 1320; m += 30) _slot(m)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Timeline(slots: slots, selectedSlot: null, onToggle: (_) {}),
        ),
      ),
    );

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.itemExtent, RecurSizes.slotRow);
  });

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

  testWidgets('a busy hour greys its own two rows and no more', (tester) async {
    // 10:00-11:00 is taken; a 60-minute appointment at 09:30 would run
    // into it.
    final slots = [
      _slot(540, durationMinutes: 60),
      _slot(
        570,
        durationMinutes: 60,
        state: SlotState.blocked,
        blockReason: BlockReason.doesNotFit,
      ),
      for (final start in [600, 630])
        _slot(
          start,
          durationMinutes: 60,
          state: SlotState.blocked,
          blockReason: BlockReason.conflict,
          blockingTitle: 'Jazz Dance Book Discussion',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Timeline(slots: slots, selectedSlot: null, onToggle: (_) {}),
        ),
      ),
    );

    SlotTile tileFor(String label) => tester.widget<SlotTile>(
      find.byWidgetPredicate((w) => w is SlotTile && w.timeLabel == label),
    );

    expect(tileFor('09:00').appearance, SlotTileAppearance.available);
    expect(tileFor('09:30').appearance, SlotTileAppearance.doesNotFit);
    expect(tileFor('09:30').reasonText, 'Not enough room');
    for (final label in ['10:00', '10:30']) {
      expect(tileFor(label).appearance, SlotTileAppearance.blocked);
      expect(tileFor(label).reasonText, 'Jazz Dance Book Discussion');
    }
  });

  testWidgets('a slot that does not fit cannot be tapped', (tester) async {
    var toggled = false;
    final slots = [
      _slot(
        570,
        durationMinutes: 60,
        state: SlotState.blocked,
        blockReason: BlockReason.doesNotFit,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Timeline(
            slots: slots,
            selectedSlot: null,
            onToggle: (_) => toggled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SlotTile));
    expect(toggled, isFalse);
  });
}
