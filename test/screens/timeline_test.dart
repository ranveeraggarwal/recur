import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/local_date.dart';
import 'package:recur/screens/booking/timeline.dart';
import 'package:recur/suggestions/slot_grid.dart';
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

  testWidgets('the hour gutter is not read on top of the tile', (tester) async {
    final handle = tester.ensureSemantics();
    final slots = [
      _slot(540),
      _slot(570),
      _slot(
        600,
        state: SlotState.blocked,
        blockReason: BlockReason.conflict,
        blockingTitle: 'Dentist',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Timeline(slots: slots, selectedSlot: null, onToggle: (_) {}),
        ),
      ),
    );

    // 09:00 and 10:00 are hour marks, so the gutter draws their time as
    // well. Only the tile's own label should carry it.
    expect(find.bySemanticsLabel('09:00'), findsNothing);
    expect(find.bySemanticsLabel('10:00'), findsNothing);
    expect(find.bySemanticsLabel('09:00, available'), findsOneWidget);
    expect(find.bySemanticsLabel('10:00, busy: Dentist'), findsOneWidget);
    handle.dispose();
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
