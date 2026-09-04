import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _loaded = false;

/// Registers the vendored Outfit faces so tests and goldens render in the
/// real app font instead of the test fallback. Safe to call repeatedly.
///
/// Call this from `setUpAll`, never from inside `testWidgets`. A widget test
/// body runs in a fake-async zone where real file I/O never completes, so
/// reading the font files there hangs until the test times out.
Future<void> loadAppFonts() async {
  if (_loaded) {
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Outfit');
  for (final name in const [
    'Outfit-Regular',
    'Outfit-Medium',
    'Outfit-SemiBold',
  ]) {
    final bytes = await File('assets/fonts/$name.ttf').readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  // `uses-material-design: true` in pubspec.yaml bundles this font into the
  // test asset manifest, so RecurFab's Icons.add renders as a real glyph in
  // goldens instead of the test-font tofu box.
  final iconLoader = FontLoader('MaterialIcons');
  iconLoader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await iconLoader.load();

  _loaded = true;
}
