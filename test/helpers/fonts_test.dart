import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Outfit is registered and renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Text('Recur', style: TextStyle(fontFamily: 'Outfit')),
      ),
    );

    final Text text = tester.widget(find.text('Recur'));
    expect(text.style?.fontFamily, 'Outfit');
  });
}
