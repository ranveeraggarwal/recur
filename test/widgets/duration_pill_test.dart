import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/widgets/duration_pill.dart';

import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('duration_pill_states', (WidgetTester tester) async {
    await pumpGolden(
      tester,
      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DurationPill(label: '45 min'),
            const SizedBox(width: 12),
            DurationPill(label: '45 min', onTap: () {}),
            const SizedBox(width: 12),
            DurationPill(label: '45 min', selected: true, onTap: () {}),
          ],
        ),
      ),
      height: 100,
    );

    await expectGolden(tester, 'duration_pill_states');
  });

  testWidgets('onTap fires on tap', (WidgetTester tester) async {
    var tapped = false;

    await pumpGolden(
      tester,
      Center(
        child: DurationPill(label: '45 min', onTap: () => tapped = true),
      ),
    );

    await tester.tap(find.byType(DurationPill));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('read-only pill has no InkWell', (WidgetTester tester) async {
    await pumpGolden(
      tester,
      const Center(child: DurationPill(label: '45 min')),
    );

    expect(find.byType(InkWell), findsNothing);
  });
}
