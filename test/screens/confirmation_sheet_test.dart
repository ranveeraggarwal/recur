import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/screens/booking/confirmation_sheet.dart';

import '../helpers/golden.dart';

Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showConfirmationSheet(
                context,
                summary: 'Tue 8 Sep, 10:00 to 11:00',
                eventTypeName: 'PT session',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shows Booked, the summary, and the card name', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('Booked'), findsOneWidget);
    expect(find.text('Tue 8 Sep, 10:00 to 11:00'), findsOneWidget);
    expect(find.text('PT session'), findsOneWidget);
  });

  testWidgets('auto-dismisses after 2 seconds', (WidgetTester tester) async {
    await _pumpSheet(tester);

    expect(find.text('Booked'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Booked'), findsNothing);
  });

  testWidgets('tapping outside dismisses it', (WidgetTester tester) async {
    await _pumpSheet(tester);

    expect(find.text('Booked'), findsOneWidget);

    // Tap the barrier well above the sheet.
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();

    expect(find.text('Booked'), findsNothing);
  });

  testWidgets('confirmation_sheet golden', (WidgetTester tester) async {
    await pumpGolden(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showConfirmationSheet(
            context,
            summary: 'Tue 8 Sep, 10:00 to 11:00',
            eventTypeName: 'PT session',
          ),
          child: const Text('open'),
        ),
      ),
      height: 400,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectGolden(tester, 'confirmation_sheet');

    // Let the auto-dismiss timer fire so the test tears down cleanly.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
