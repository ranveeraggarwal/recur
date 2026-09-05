import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/screens/editor/event_prefill.dart';
import 'package:recur/screens/editor/prefill_sheet.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

CalendarEvent _event({
  required String id,
  required String title,
  required DateTime start,
  int durationMinutes = 60,
  String? location,
}) {
  return CalendarEvent(
    id: id,
    calendarId: 'cal-1',
    title: title,
    start: start,
    end: start.add(Duration(minutes: durationMinutes)),
    isAllDay: false,
    location: location,
  );
}

Future<EventPrefill?> _pumpAndOpen(
  WidgetTester tester,
  TestDeps testDeps,
) async {
  EventPrefill? result;
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPrefillSheet(context);
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

  testWidgets('lists one row per title, newest first', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.addAll([
      _event(
        id: 'a',
        title: 'Physio',
        start: DateTime(2026, 9, 1, 10),
        durationMinutes: 45,
        location: 'Vasastan',
      ),
      _event(id: 'b', title: 'Haircut', start: DateTime(2026, 9, 4, 17)),
      _event(id: 'c', title: 'Physio', start: DateTime(2026, 8, 18, 10)),
    ]);

    await _pumpAndOpen(tester, testDeps);

    expect(find.text('Copy from calendar'), findsOneWidget);
    expect(find.text('Physio'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('60 min · Fri 4 Sep'), findsOneWidget);
    expect(find.text('45 min · Tue 1 Sep · Vasastan'), findsOneWidget);
  });

  testWidgets('tapping a row returns its prefill', (WidgetTester tester) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', title: 'Physio', start: DateTime(2026, 9, 1, 10)),
    );

    await _pumpAndOpen(tester, testDeps);
    await tester.tap(find.text('Physio'));
    await tester.pumpAndSettle();

    expect(find.text('Copy from calendar'), findsNothing);
  });

  testWidgets('says so when there is nothing to copy', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();

    await _pumpAndOpen(tester, testDeps);

    expect(find.text('Nothing in your calendar to copy.'), findsOneWidget);
  });

  testWidgets('reads a season either side of today', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.addAll([
      // Two years ago, and two months ahead: both out of range.
      _event(id: 'a', title: 'Ancient', start: DateTime(2024, 9, 1, 10)),
      _event(id: 'b', title: 'Distant', start: DateTime(2026, 11, 30, 10)),
      _event(id: 'c', title: 'Recent', start: DateTime(2026, 8, 20, 10)),
    ]);

    await _pumpAndOpen(tester, testDeps);

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Ancient'), findsNothing);
    expect(find.text('Distant'), findsNothing);
  });

  testWidgets('prefill_sheet golden', (WidgetTester tester) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.addAll([
      _event(
        id: 'a',
        title: 'Physio',
        start: DateTime(2026, 9, 1, 10),
        durationMinutes: 45,
        location: 'Vasastan',
      ),
      _event(id: 'b', title: 'Haircut', start: DateTime(2026, 9, 4, 17)),
    ]);

    await pumpGolden(
      tester,
      AppScope(
        deps: testDeps.deps,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPrefillSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
      height: 500,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectGolden(tester, 'prefill_sheet');
  });
}
