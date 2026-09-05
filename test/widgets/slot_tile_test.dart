import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/widgets/slot_tile.dart';

import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  group('SlotTile behaviour', () {
    testWidgets('available tile fires onTap', (tester) async {
      var tapped = false;
      await pumpGolden(
        tester,
        SlotTile(
          timeLabel: '09:00',
          appearance: SlotTileAppearance.available,
          onTap: () => tapped = true,
        ),
        height: 60,
      );

      await tester.tap(find.byType(SlotTile));
      expect(tapped, isTrue);
    });

    testWidgets('highlighted tile fires onTap', (tester) async {
      var tapped = false;
      await pumpGolden(
        tester,
        SlotTile(
          timeLabel: '09:30',
          appearance: SlotTileAppearance.highlighted,
          onTap: () => tapped = true,
        ),
        height: 60,
      );

      await tester.tap(find.byType(SlotTile));
      expect(tapped, isTrue);
    });

    testWidgets('blocked tile does not fire onTap', (tester) async {
      var tapped = false;
      await pumpGolden(
        tester,
        SlotTile(
          timeLabel: '11:30',
          appearance: SlotTileAppearance.blocked,
          reasonText: 'Past',
          onTap: () => tapped = true,
        ),
        height: 60,
      );

      await tester.tap(find.byType(SlotTile));
      expect(tapped, isFalse);
    });

    testWidgets('does-not-fit tile does not fire onTap', (tester) async {
      var tapped = false;
      await pumpGolden(
        tester,
        SlotTile(
          timeLabel: '09:30',
          appearance: SlotTileAppearance.doesNotFit,
          reasonText: 'Not enough room',
          onTap: () => tapped = true,
        ),
        height: 60,
      );

      await tester.tap(find.byType(SlotTile));
      expect(tapped, isFalse);
    });

    testWidgets('selected tile fires onTap (toggles off)', (tester) async {
      var tapped = false;
      await pumpGolden(
        tester,
        SlotTile(
          timeLabel: '10:00',
          appearance: SlotTileAppearance.selected,
          onTap: () => tapped = true,
        ),
        height: 60,
      );

      await tester.tap(find.byType(SlotTile));
      expect(tapped, isTrue);
    });
  });

  testWidgets('slot_tile_states golden', (tester) async {
    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.only(left: 56, right: 16),
        child: Column(
          children: [
            SlotTile(
              timeLabel: '09:00',
              appearance: SlotTileAppearance.available,
              onTap: () {},
            ),
            SlotTile(
              timeLabel: '09:30',
              appearance: SlotTileAppearance.highlighted,
              onTap: () {},
            ),
            SlotTile(
              timeLabel: '10:00',
              appearance: SlotTileAppearance.selected,
              onTap: () {},
            ),
            const SlotTile(
              timeLabel: '10:30',
              appearance: SlotTileAppearance.blocked,
              reasonText: 'Dentist',
            ),
            const SlotTile(
              timeLabel: '11:00',
              appearance: SlotTileAppearance.blocked,
              reasonText: 'Busy',
            ),
            const SlotTile(
              timeLabel: '11:30',
              appearance: SlotTileAppearance.blocked,
              reasonText: 'Past',
            ),
            const SlotTile(
              timeLabel: '21:30',
              appearance: SlotTileAppearance.blocked,
              reasonText: 'Outside hours',
            ),
            const SlotTile(
              timeLabel: '12:00',
              appearance: SlotTileAppearance.doesNotFit,
              reasonText: 'Not enough room',
            ),
          ],
        ),
      ),
      height: 450,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/slot_tile_states.png'),
    );
  });
}
