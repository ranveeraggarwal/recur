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

  group('SlotTile semantics', () {
    Future<void> pumpTile(
      WidgetTester tester, {
      required String timeLabel,
      required SlotTileAppearance appearance,
      String? reasonText,
    }) async {
      await pumpGolden(
        tester,
        SlotTile(
          timeLabel: timeLabel,
          appearance: appearance,
          reasonText: reasonText,
          onTap: () {},
        ),
        height: 60,
      );
    }

    testWidgets('an available tile reads as an available button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTile(
        tester,
        timeLabel: '10:00',
        appearance: SlotTileAppearance.available,
      );

      expect(
        tester.getSemantics(find.byType(SlotTile)),
        matchesSemantics(
          label: '10:00, available',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a highlighted tile reads as suggested', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTile(
        tester,
        timeLabel: '10:00',
        appearance: SlotTileAppearance.highlighted,
      );

      expect(
        tester.getSemantics(find.byType(SlotTile)),
        matchesSemantics(
          label: '10:00, suggested',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a selected tile reads as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTile(
        tester,
        timeLabel: '10:00',
        appearance: SlotTileAppearance.selected,
      );

      expect(
        tester.getSemantics(find.byType(SlotTile)),
        matchesSemantics(
          label: '10:00, selected',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a tile blocked by an event names the event', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTile(
        tester,
        timeLabel: '10:00',
        appearance: SlotTileAppearance.blocked,
        reasonText: 'Dentist',
      );

      expect(
        tester.getSemantics(find.byType(SlotTile)),
        matchesSemantics(
          label: '10:00, busy: Dentist',
          hasEnabledState: true,
          isEnabled: false,
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('the fixed block reasons read as themselves', (tester) async {
      final handle = tester.ensureSemantics();

      for (final (reason, label) in const [
        ('Past', '10:00, past'),
        ('Outside hours', '10:00, outside hours'),
        ('Busy', '10:00, busy'),
      ]) {
        await pumpTile(
          tester,
          timeLabel: '10:00',
          appearance: SlotTileAppearance.blocked,
          reasonText: reason,
        );

        expect(
          tester.getSemantics(find.byType(SlotTile)),
          matchesSemantics(
            label: label,
            hasEnabledState: true,
            isEnabled: false,
            hasSelectedState: true,
            isSelected: false,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('a does-not-fit tile reads its reason and is not a button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpTile(
        tester,
        timeLabel: '10:00',
        appearance: SlotTileAppearance.doesNotFit,
        reasonText: 'Not enough room',
      );

      expect(
        tester.getSemantics(find.byType(SlotTile)),
        matchesSemantics(
          label: '10:00, not enough room',
          hasEnabledState: true,
          isEnabled: false,
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('the time and the reason are not read twice', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTile(
        tester,
        timeLabel: '10:00',
        appearance: SlotTileAppearance.blocked,
        reasonText: 'Dentist',
      );

      expect(find.bySemanticsLabel('10:00'), findsNothing);
      expect(find.bySemanticsLabel('Dentist'), findsNothing);
      handle.dispose();
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
