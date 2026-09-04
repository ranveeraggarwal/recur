import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/widgets/recur_fab.dart';

import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('fab_default', (WidgetTester tester) async {
    await pumpGolden(
      tester,
      Center(child: RecurFab(onPressed: () {})),
      height: 120,
    );

    await expectGolden(tester, 'fab_default');
  });

  testWidgets('RecurFab fires onPressed when tapped', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await pumpGolden(tester, RecurFab(onPressed: () => tapped = true));

    await tester.tap(find.byType(RecurFab));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
