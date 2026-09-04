import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

void main() {
  testWidgets('Outfit is registered and renders', (WidgetTester tester) async {
    await loadAppFonts();
    await tester.pumpWidget(
      const MaterialApp(
        home: Text('Recur', style: TextStyle(fontFamily: 'Outfit')),
      ),
    );
    expect(find.text('Recur'), findsOneWidget);
  });
}
