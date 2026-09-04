import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app.dart';

import 'helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('home_empty_shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(goldenWidth, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RecurApp());
    await tester.pumpAndSettle();

    await expectGolden(tester, 'home_empty_shell');
  });
}
