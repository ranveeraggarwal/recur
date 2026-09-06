import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/widgets/day_pill.dart';

import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  group('DayPill behaviour', () {
    testWidgets('enabled pill fires onTap', (tester) async {
      var tapped = false;
      await pumpGolden(
        tester,
        DayPill(
          weekdayLabel: 'Mon',
          dayNumber: 7,
          selected: false,
          enabled: true,
          hasSuggestions: false,
          isToday: false,
          onTap: () => tapped = true,
        ),
        height: 80,
      );

      await tester.tap(find.byType(DayPill));
      expect(tapped, isTrue);
    });

    testWidgets('disabled pill does not fire onTap', (tester) async {
      var tapped = false;
      await pumpGolden(
        tester,
        DayPill(
          weekdayLabel: 'Thu',
          dayNumber: 10,
          selected: false,
          enabled: false,
          hasSuggestions: false,
          isToday: false,
          onTap: () => tapped = true,
        ),
        height: 80,
      );

      await tester.tap(find.byType(DayPill));
      expect(tapped, isFalse);
    });
  });

  group('DayPill semantics', () {
    Future<void> pumpPill(
      WidgetTester tester, {
      String weekdayLabel = 'Tue',
      int dayNumber = 8,
      bool selected = false,
      bool enabled = true,
      bool hasSuggestions = false,
      bool isToday = false,
    }) async {
      await pumpGolden(
        tester,
        DayPill(
          weekdayLabel: weekdayLabel,
          dayNumber: dayNumber,
          selected: selected,
          enabled: enabled,
          hasSuggestions: hasSuggestions,
          isToday: isToday,
          onTap: () {},
        ),
        height: 80,
      );
    }

    testWidgets('a plain pill reads the full weekday and the day', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPill(tester);

      expect(
        tester.getSemantics(find.byType(DayPill)),
        matchesSemantics(
          label: 'Tuesday 8',
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

    testWidgets('today, the dot and the selection are all read', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPill(
        tester,
        selected: true,
        hasSuggestions: true,
        isToday: true,
      );

      expect(
        tester.getSemantics(find.byType(DayPill)),
        matchesSemantics(
          label: 'Tuesday 8, today, has good slots',
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

    testWidgets('a past pill reads as disabled and claims no good slots', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPill(
        tester,
        weekdayLabel: 'Mon',
        dayNumber: 7,
        enabled: false,
        hasSuggestions: true,
      );

      expect(
        tester.getSemantics(find.byType(DayPill)),
        matchesSemantics(
          label: 'Monday 7',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('the weekday and the day number are not read twice', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPill(tester);

      expect(find.bySemanticsLabel('Tue'), findsNothing);
      expect(find.bySemanticsLabel('8'), findsNothing);
      handle.dispose();
    });
  });

  testWidgets('day_pill_states golden', (tester) async {
    await pumpGolden(
      tester,
      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DayPill(
              weekdayLabel: 'Mon',
              dayNumber: 7,
              selected: false,
              enabled: true,
              hasSuggestions: false,
              isToday: false,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            DayPill(
              weekdayLabel: 'Tue',
              dayNumber: 8,
              selected: false,
              enabled: true,
              hasSuggestions: false,
              isToday: true,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            DayPill(
              weekdayLabel: 'Wed',
              dayNumber: 9,
              selected: true,
              enabled: true,
              hasSuggestions: false,
              isToday: false,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            const DayPill(
              weekdayLabel: 'Thu',
              dayNumber: 10,
              selected: false,
              enabled: false,
              hasSuggestions: false,
              isToday: false,
            ),
            const SizedBox(width: 8),
            DayPill(
              weekdayLabel: 'Fri',
              dayNumber: 11,
              selected: false,
              enabled: true,
              hasSuggestions: true,
              isToday: false,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            DayPill(
              weekdayLabel: 'Sat',
              dayNumber: 12,
              selected: true,
              enabled: true,
              hasSuggestions: true,
              isToday: false,
              onTap: () {},
            ),
          ],
        ),
      ),
      height: 96,
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/day_pill_states.png'),
    );
  });
}
