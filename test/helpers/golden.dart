import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/theme/app_theme.dart';

export 'fonts.dart' show loadAppFonts;

/// The viewport width every golden is taken at, per `docs/architecture.md`.
const double goldenWidth = 380.0;

/// Sets the view to [goldenWidth] x [height] logical px at device pixel
/// ratio 1, wraps [child] in Recur's theme (and a [Scaffold] when
/// [scaffold] is true), pumps it, and settles.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  double height = 800,
  bool scaffold = true,
}) async {
  tester.view.physicalSize = Size(goldenWidth, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildRecurTheme(),
      home: scaffold ? Scaffold(body: child) : child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Compares the current [MaterialApp] against `test/goldens/$name.png`.
///
/// Resolved as an absolute path from the package root (where `flutter
/// test` runs), rather than relative to the calling test file, so every
/// golden test — regardless of which subdirectory it lives in — reads and
/// writes `test/goldens/`, never a `goldens/` folder alongside itself.
Future<void> expectGolden(WidgetTester tester, String name) async {
  final file = File('test/goldens/$name.png');
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(file.absolute.uri),
  );
}
