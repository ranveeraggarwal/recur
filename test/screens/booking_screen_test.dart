import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/local_date.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/booking/booking_screen.dart';
import 'package:recur/screens/booking/timeline.dart';
import 'package:recur/theme/tokens.dart';
import 'package:recur/widgets/day_pill.dart';
import 'package:recur/widgets/slot_tile.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

/// `PT session`, 60 min, Kungsholmen, preferred Tue/Thu 09:00-12:00.
EventType _ptSession() {
  return EventType(
    id: 'et-1',
    name: 'PT session',
    durationMinutes: 60,
    location: 'Kungsholmen',
    preferredWeekdays: const {2, 4},
    preferredWindows: [TimeWindow(startMinutes: 540, endMinutes: 720)],
    createdAt: DateTime(2020, 1, 1),
  );
}

/// `Late PT`, 60 min, preferred Wednesdays only, 16:00-18:00.
EventType _wednesdayAfternoon() {
  return EventType(
    id: 'et-1',
    name: 'Late PT',
    durationMinutes: 60,
    preferredWeekdays: const {3},
    preferredWindows: [TimeWindow(startMinutes: 960, endMinutes: 1080)],
    createdAt: DateTime(2020, 1, 1),
  );
}

/// Pushes [BookingScreen] on top of a root screen, so a test can see the
/// route pop.
Future<void> _pumpBookingPushed(
  WidgetTester tester,
  TestDeps testDeps, {
  String eventTypeId = 'et-1',
}) async {
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookingScreen(eventTypeId: eventTypeId),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
}

double _timelineOffset(WidgetTester tester) =>
    tester.widget<Timeline>(find.byType(Timeline)).scrollController!.offset;

Future<void> _pumpBooking(WidgetTester tester, TestDeps testDeps) async {
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: const MaterialApp(home: BookingScreen(eventTypeId: 'et-1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shows the card name, subtitle, and Pick a slot', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    expect(find.text('PT session'), findsOneWidget);
    expect(find.text('60 min · Kungsholmen'), findsOneWidget);
    expect(find.text('Pick a slot'), findsOneWidget);
  });

  testWidgets('tapping an available slot selects it and updates the summary', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    await tester.tap(find.text('09:30'));
    await tester.pumpAndSettle();

    expect(find.text('Mon 7 Sep, 09:30 to 10:30'), findsOneWidget);
  });

  testWidgets('the forward chevron shows next week and enables the back one', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    expect(find.text('Week of 7 Sep'), findsOneWidget);
    final backButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(backButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Week of 14 Sep'), findsOneWidget);
    final backButtonAfter = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(backButtonAfter.onPressed, isNotNull);
  });

  testWidgets('selecting a day switches the timeline', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    final tuesdayPill = tester
        .widgetList<DayPill>(find.byType(DayPill))
        .firstWhere((p) => p.weekdayLabel == 'Tue');
    expect(tuesdayPill.selected, isFalse);

    await tester.tap(find.text('Tue').first);
    await tester.pumpAndSettle();

    final tuesdayPillAfter = tester
        .widgetList<DayPill>(find.byType(DayPill))
        .firstWhere((p) => p.weekdayLabel == 'Tue');
    expect(tuesdayPillAfter.selected, isTrue);
  });

  testWidgets('the timeline opens on the first highlighted slot of the day '
      'switched to', (WidgetTester tester) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_wednesdayAfternoon());
    await _pumpBooking(tester, testDeps);

    // Monday has no highlighted slot, so it opens on the 08:00 row.
    expect(_timelineOffset(tester), 4 * RecurSizes.slotRow);

    await tester.tap(find.text('Wed'));
    await tester.pumpAndSettle();

    // 16:00 is the twenty-first row: (960 - 360) / 30 = 20.
    expect(_timelineOffset(tester), 20 * RecurSizes.slotRow);
  });

  testWidgets('a day whose first good slot is already on screen does not '
      'move the timeline', (WidgetTester tester) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    final before = _timelineOffset(tester);

    // Tuesday's first highlighted slot is 09:00, two rows below the 08:00
    // row Monday opened on, so it is already in front of the user.
    await tester.tap(find.text('Tue').first);
    await tester.pumpAndSettle();

    expect(_timelineOffset(tester), before);
  });

  testWidgets('selecting a slot keeps the timeline where it is', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_wednesdayAfternoon());
    await _pumpBooking(tester, testDeps);

    await tester.tap(find.text('Wed'));
    await tester.pumpAndSettle();
    final before = _timelineOffset(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is SlotTile && widget.timeLabel == '16:00',
      ),
    );
    await tester.pumpAndSettle();

    expect(_timelineOffset(tester), before);
  });

  testWidgets('a card that no longer exists pops the route', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();

    await _pumpBookingPushed(tester, testDeps, eventTypeId: 'missing');

    // Back on the page underneath, rather than stuck on a blank screen
    // with no app bar to leave by.
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(BookingScreen), findsNothing);
  });

  testWidgets('an unreadable card says so, with an app bar to leave by', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.store.write('event_types', 'not json');

    await _pumpBookingPushed(tester, testDeps);

    expect(find.text("Couldn't open this card."), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('coming back after midnight moves today', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps(now: DateTime(2026, 9, 7, 23, 59));
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    DayPill pillFor(String label) => tester
        .widgetList<DayPill>(find.byType(DayPill))
        .firstWhere((p) => p.weekdayLabel == label);

    expect(pillFor('Mon').isToday, isTrue);

    testDeps.clock.advance(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(pillFor('Mon').isToday, isFalse);
    expect(pillFor('Mon').enabled, isFalse);
    expect(pillFor('Tue').isToday, isTrue);
  });

  group('goldens', () {
    testWidgets('booking_week', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await expectGolden(tester, 'booking_week');
    });

    testWidgets('booking_busy_hour', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      final tuesday = LocalDate(2026, 9, 8);
      testDeps.calendar.busy.add(
        BusyInterval(
          start: tuesday.at(600), // 10:00
          end: tuesday.at(660), // 11:00
          title: 'Jazz Dance Book Discussion',
        ),
      );

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();

      await expectGolden(tester, 'booking_busy_hour');
    });

    testWidgets('booking_selected', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await tester.tap(find.text('Tue').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is SlotTile && widget.timeLabel == '09:30',
        ),
      );
      await tester.pumpAndSettle();

      await expectGolden(tester, 'booking_selected');
    });

    testWidgets('booking_next_week', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      await expectGolden(tester, 'booking_next_week');
    });
  });
}
