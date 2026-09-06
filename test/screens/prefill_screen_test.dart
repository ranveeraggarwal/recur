import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/screens/editor/event_prefill.dart';
import 'package:recur/screens/editor/prefill_screen.dart';
import 'package:recur/widgets/day_pill.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

CalendarEvent _event({
  required String id,
  String title = 'Physio',
  required DateTime start,
  int durationMinutes = 60,
  bool isAllDay = false,
  String? location,
  String? notes,
}) {
  return CalendarEvent(
    id: id,
    calendarId: 'cal-1',
    title: title,
    start: start,
    end: start.add(Duration(minutes: durationMinutes)),
    isAllDay: isAllDay,
    location: location,
    notes: notes,
  );
}

/// Pumps a root screen and pushes [PrefillScreen] from it, so backing out
/// or picking an event has somewhere to return to.
Future<void> _pumpAndOpen(WidgetTester tester, TestDeps testDeps) async {
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<EventPrefill>(
                  MaterialPageRoute(
                    builder: (context) => const PrefillScreen(),
                  ),
                ),
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
}

void main() {
  setUpAll(loadAppFonts);

  // FixedClock defaults to Monday 2026-09-07 09:00.
  final tuesday = DateTime(2026, 9, 8);

  testWidgets('shows this week, with today selected', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', start: tuesday.add(const Duration(hours: 10))),
    );

    await _pumpAndOpen(tester, testDeps);

    expect(find.text('Copy from calendar'), findsOneWidget);
    expect(find.text('Week of 7 Sep'), findsOneWidget);
    final pills = tester.widgetList<DayPill>(find.byType(DayPill)).toList();
    expect(pills, hasLength(7));
    expect(pills[0].selected, isTrue); // Monday, today
    expect(pills[0].isToday, isTrue);
  });

  testWidgets('a day with events wears the dot, and past days stay live', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', start: tuesday.add(const Duration(hours: 10))),
    );

    await _pumpAndOpen(tester, testDeps);

    final pills = tester.widgetList<DayPill>(find.byType(DayPill)).toList();
    expect(pills[1].hasSuggestions, isTrue); // Tuesday has the event
    expect(pills[2].hasSuggestions, isFalse);
    // Copying looks backwards, so every day is pickable.
    expect(pills.every((p) => p.enabled), isTrue);
  });

  testWidgets('tapping a day shows that day\'s events', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', start: tuesday.add(const Duration(hours: 10))),
    );

    await _pumpAndOpen(tester, testDeps);
    expect(find.text('Nothing on this day.'), findsOneWidget);

    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();

    expect(find.text('Physio'), findsOneWidget);
    expect(find.text('10:00 to 11:00'), findsOneWidget);
  });

  testWidgets('an event block shows its time and place', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(
        id: 'a',
        start: tuesday.add(const Duration(hours: 10)),
        durationMinutes: 45,
        location: 'Vasastan',
      ),
    );

    await _pumpAndOpen(tester, testDeps);
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();

    expect(find.text('10:00 to 10:45 · Vasastan'), findsOneWidget);
  });

  testWidgets('the popped prefill carries the location of an earlier '
      'occurrence', (WidgetTester tester) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.addAll([
      _event(
        id: 'a',
        start: DateTime(2026, 9, 1, 10),
        durationMinutes: 45,
        location: 'Vasastan',
        notes: 'Bring the referral',
      ),
      _event(
        id: 'b',
        start: tuesday.add(const Duration(hours: 10)),
        durationMinutes: 45,
      ),
    ]);

    EventPrefill? picked;
    await tester.pumpWidget(
      AppScope(
        deps: testDeps.deps,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    picked = await Navigator.of(context).push<EventPrefill>(
                      MaterialPageRoute(
                        builder: (context) => const PrefillScreen(),
                      ),
                    );
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
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Physio'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.name, 'Physio');
    expect(picked!.durationMinutes, 45);
    expect(picked!.location, 'Vasastan');
    expect(picked!.notes, 'Bring the referral');
    expect(picked!.occurrences, 2);
  });

  testWidgets('the previous week is reachable, unlike Booking', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', start: DateTime(2026, 9, 1, 10)),
    );

    await _pumpAndOpen(tester, testDeps);
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();

    expect(find.text('Week of 31 Aug'), findsOneWidget);
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();
    expect(find.text('Physio'), findsOneWidget);
  });

  testWidgets('the chevrons stop at the edges of the range read', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', start: tuesday.add(const Duration(hours: 10))),
    );

    await _pumpAndOpen(tester, testDeps);

    // 30 days ahead is under five weeks out.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
    }
    final next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('all-day and untitled events are not offered', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.addAll([
      _event(
        id: 'a',
        title: 'Holiday',
        start: tuesday,
        durationMinutes: 1440,
        isAllDay: true,
      ),
      _event(
        id: 'b',
        title: '   ',
        start: tuesday.add(const Duration(hours: 9)),
      ),
    ]);

    await _pumpAndOpen(tester, testDeps);

    // Neither could be a card, so there is nothing to show at all.
    expect(find.text('Holiday'), findsNothing);
    expect(find.text('Nothing in your calendar to copy.'), findsOneWidget);
  });

  testWidgets('an all-day event does not hide the day\'s real ones', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.addAll([
      _event(
        id: 'a',
        title: 'Holiday',
        start: tuesday,
        durationMinutes: 1440,
        isAllDay: true,
      ),
      _event(
        id: 'b',
        title: 'Physio',
        start: tuesday.add(const Duration(hours: 10)),
      ),
    ]);

    await _pumpAndOpen(tester, testDeps);
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();

    expect(find.text('Holiday'), findsNothing);
    expect(find.text('Physio'), findsOneWidget);
  });

  testWidgets('an early event still lands on the grid', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', start: tuesday.add(const Duration(hours: 5))),
    );

    await _pumpAndOpen(tester, testDeps);
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();

    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Physio'), findsOneWidget);
  });

  testWidgets('an empty calendar says so', (WidgetTester tester) async {
    final testDeps = buildTestDeps();

    await _pumpAndOpen(tester, testDeps);

    expect(find.text('Nothing in your calendar to copy.'), findsOneWidget);
  });

  testWidgets('without calendar access it asks for it', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.access = CalendarAccess.denied;
    testDeps.calendar.events.add(
      _event(id: 'a', start: tuesday.add(const Duration(hours: 10))),
    );

    await _pumpAndOpen(tester, testDeps);

    expect(
      find.text('Recur needs calendar access to copy an event.'),
      findsOneWidget,
    );
  });

  testWidgets('two overlapping events share the width', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.addAll([
      _event(
        id: 'a',
        title: 'Physio',
        start: tuesday.add(const Duration(hours: 10)),
      ),
      _event(
        id: 'b',
        title: 'Standup',
        start: tuesday.add(const Duration(hours: 10, minutes: 30)),
      ),
    ]);

    await _pumpAndOpen(tester, testDeps);
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();

    final physio = tester.getRect(find.text('Physio'));
    final standup = tester.getRect(find.text('Standup'));
    expect(find.text('Physio'), findsOneWidget);
    expect(find.text('Standup'), findsOneWidget);
    // Side by side, not stacked on top of each other.
    expect(physio.left, isNot(standup.left));
  });

  group('goldens', () {
    testWidgets('prefill_week', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.events.addAll([
        _event(
          id: 'a',
          title: 'Physio',
          start: tuesday.add(const Duration(hours: 10)),
          durationMinutes: 45,
          location: 'Vasastan',
        ),
        _event(
          id: 'b',
          title: 'Chicago "Swing" Jam Session',
          start: tuesday.add(const Duration(hours: 12)),
          durationMinutes: 90,
        ),
      ]);

      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const PrefillScreen()),
        height: 900,
        scaffold: false,
      );

      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      await expectGolden(tester, 'prefill_week');
    });

    testWidgets('prefill_empty_day', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.events.add(
        _event(id: 'a', start: tuesday.add(const Duration(hours: 10))),
      );

      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const PrefillScreen()),
        height: 900,
        scaffold: false,
      );

      await expectGolden(tester, 'prefill_empty_day');
    });
  });
}
