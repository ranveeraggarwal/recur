import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Registers the vendored Outfit faces so tests and goldens render in the
/// real app font instead of the test fallback. Safe to call repeatedly.
Future<void> loadAppFonts() async {
  if (_loaded) {
    return;
  }
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
  _loaded = true;
}
