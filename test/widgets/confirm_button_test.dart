import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/theme/tokens.dart';
import 'package:recur/widgets/confirm_button.dart';

import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('confirm_button_states', (WidgetTester tester) async {
    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(RecurSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConfirmButton(label: 'Confirm', onPressed: () {}),
            const SizedBox(height: RecurSpacing.lg),
            const ConfirmButton(label: 'Confirm', onPressed: null),
            const SizedBox(height: RecurSpacing.lg),
            ConfirmButton(label: 'Confirm', onPressed: () {}, busy: true),
          ],
        ),
      ),
      height: 260,
      settle: false,
    );

    await expectGolden(tester, 'confirm_button_states');
  });

  testWidgets('confirm_bar', (WidgetTester tester) async {
    await pumpGolden(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ConfirmBar(
          summary: 'Tue 8 Sep, 10:00 to 11:00',
          button: ConfirmButton(label: 'Confirm', onPressed: () {}),
        ),
      ),
      height: 160,
    );

    await expectGolden(tester, 'confirm_bar');
  });

  testWidgets('enabled ConfirmButton fires onPressed when tapped', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await pumpGolden(
      tester,
      ConfirmButton(label: 'Confirm', onPressed: () => tapped = true),
    );

    await tester.tap(find.byType(ConfirmButton));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('disabled ConfirmButton does not fire onPressed', (
    WidgetTester tester,
  ) async {
    await pumpGolden(
      tester,
      const ConfirmButton(label: 'Confirm', onPressed: null),
    );

    await tester.tap(find.byType(ConfirmButton));
    await tester.pumpAndSettle();

    // No throw, and nothing to assert against onPressed being null; the
    // absence of a callback is the guarantee. Reaching here without error
    // confirms the tap was a no-op.
  });

  testWidgets('busy ConfirmButton ignores taps', (WidgetTester tester) async {
    var tapped = false;
    await pumpGolden(
      tester,
      ConfirmButton(
        label: 'Confirm',
        onPressed: () => tapped = true,
        busy: true,
      ),
      settle: false,
    );

    await tester.tap(find.byType(ConfirmButton));
    await tester.pump();

    expect(tapped, isFalse);
  });
}
