import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/data/models/app_settings.dart';
import 'package:recur/screens/booking/calendar_picker_sheet.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

Future<String?> _pumpAndOpen(WidgetTester tester, TestDeps testDeps) async {
  String? result;
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showCalendarPicker(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'shows one row per writable calendar with a check on the selection',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.calendars = [
        const CalendarInfo(
          id: 'cal-1',
          name: 'Personal',
          accountName: 'me@example.com',
          isPrimary: true,
        ),
        const CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false),
      ];
      await testDeps.deps.settings.save(
        const AppSettings(selectedCalendarId: 'cal-2'),
      );
      await _pumpAndOpen(tester, testDeps);

      expect(find.text('Write bookings to'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('me@example.com'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets('tapping a row stores the choice and closes the sheet', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.calendars = [
      const CalendarInfo(id: 'cal-1', name: 'Personal', isPrimary: true),
      const CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false),
    ];
    String? chosen;

    await tester.pumpWidget(
      AppScope(
        deps: testDeps.deps,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    chosen = await showCalendarPicker(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(chosen, 'cal-2');
    expect(find.text('Write bookings to'), findsNothing);
    expect((await testDeps.deps.settings.get()).selectedCalendarId, 'cal-2');
  });

  testWidgets('calendar_picker_sheet golden', (WidgetTester tester) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.calendars = [
      const CalendarInfo(
        id: 'cal-1',
        name: 'Personal',
        accountName: 'me@example.com',
        isPrimary: true,
      ),
      const CalendarInfo(
        id: 'cal-2',
        name: 'Work',
        accountName: 'me@work.com',
        isPrimary: false,
      ),
    ];
    await testDeps.deps.settings.save(
      const AppSettings(selectedCalendarId: 'cal-1'),
    );

    await pumpGolden(
      tester,
      AppScope(
        deps: testDeps.deps,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showCalendarPicker(context),
            child: const Text('open'),
          ),
        ),
      ),
      height: 500,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectGolden(tester, 'calendar_picker_sheet');
  });
}
