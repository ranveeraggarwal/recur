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

    await expectGolden(tester, 'day_pill_states');
  });
}
