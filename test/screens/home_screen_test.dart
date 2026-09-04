import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/data/models/booking.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/home/home_screen.dart';
import 'package:recur/widgets/event_card.dart';
import 'package:recur/widgets/recur_fab.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

EventType _eventType({
  required String id,
  required String name,
  int durationMinutes = 60,
  String? location,
  DateTime? createdAt,
}) {
  return EventType(
    id: id,
    name: name,
    durationMinutes: durationMinutes,
    location: location,
    preferredWeekdays: const {1, 2, 3, 4, 5},
    preferredStartMinutes: 480,
    preferredEndMinutes: 1080,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

Booking _booking({
  required String id,
  required String eventTypeId,
  required DateTime start,
}) {
  return Booking(
    id: id,
    eventTypeId: eventTypeId,
    start: start,
    end: start.add(const Duration(hours: 1)),
    calendarId: 'cal-1',
    calendarEventId: 'evt-$id',
    createdAt: start,
  );
}

Future<void> _pumpHome(WidgetTester tester, TestDeps testDeps) async {
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shows the empty state when there are no cards', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await _pumpHome(tester, testDeps);

    expect(find.text('No events yet.'), findsOneWidget);
    expect(find.text('Tap + to add one.'), findsOneWidget);
  });

  testWidgets(
    'shows cards with the correct column radii and last-booked text',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-1',
          name: 'PT session',
          durationMinutes: 60,
          location: 'Kungsholmen',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-2',
          name: 'Physio',
          durationMinutes: 45,
          createdAt: DateTime(2026, 1, 2),
        ),
      );
      await testDeps.deps.bookings.add(
        _booking(
          id: 'b-1',
          eventTypeId: 'et-1',
          start: DateTime(2026, 8, 17, 10),
        ),
      );

      await _pumpHome(tester, testDeps);

      final cards = tester
          .widgetList<EventCard>(find.byType(EventCard))
          .toList();
      expect(cards, hasLength(2));
      expect(cards[0].column, CardColumn.one);
      expect(cards[1].column, CardColumn.two);
      expect(cards[0].lastBookedText, 'Last booked 3 weeks ago');
      expect(cards[0].lastBookedIsFuture, isFalse);
      expect(cards[1].lastBookedText, 'Not booked yet');
    },
  );

  testWidgets('a future booking shows Booked for ... in primary', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session'),
    );
    await testDeps.deps.bookings.add(
      _booking(
        id: 'b-1',
        eventTypeId: 'et-1',
        start: DateTime(2026, 9, 10, 10),
      ),
    );

    await _pumpHome(tester, testDeps);

    final card = tester.widget<EventCard>(find.byType(EventCard));
    expect(card.lastBookedText, 'Booked for Thu 10 Sep');
    expect(card.lastBookedIsFuture, isTrue);
  });

  testWidgets('no calendar icon with only one writable calendar', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await _pumpHome(tester, testDeps);
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
  });

  testWidgets('the calendar icon appears with two or more writable calendars', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.calendars = [
      ...testDeps.calendar.calendars,
      const CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false),
    ];
    await _pumpHome(tester, testDeps);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });

  testWidgets('the FAB navigates to the Editor for a new card', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await _pumpHome(tester, testDeps);

    await tester.tap(find.byType(RecurFab));
    await tester.pumpAndSettle();

    expect(find.text('New event'), findsOneWidget);
  });

  testWidgets(
    'tap opens Booking and long-press opens Editor with the right id',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(
        _eventType(id: 'et-1', name: 'PT session'),
      );
      await _pumpHome(tester, testDeps);

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();
      expect(find.text('PT session'), findsWidgets);
      expect(find.text('Pick a slot'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(EventCard));
      await tester.pumpAndSettle();
      expect(find.text('Edit event'), findsOneWidget);
      expect(find.text('PT session'), findsWidgets);
    },
  );

  group('goldens', () {
    testWidgets('home_empty', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const HomeScreen()),
        scaffold: false,
      );

      await expectGolden(tester, 'home_empty');
    });

    testWidgets('home_two_cards', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-1',
          name: 'PT session',
          durationMinutes: 60,
          location: 'Kungsholmen',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-2',
          name: 'Physio',
          durationMinutes: 45,
          createdAt: DateTime(2026, 1, 2),
        ),
      );
      await testDeps.deps.bookings.add(
        _booking(
          id: 'b-1',
          eventTypeId: 'et-1',
          start: DateTime(2026, 8, 17, 10),
        ),
      );

      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const HomeScreen()),
        scaffold: false,
      );

      await expectGolden(tester, 'home_two_cards');
    });

    testWidgets('home_five_cards', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      for (var i = 1; i <= 5; i++) {
        await testDeps.deps.eventTypes.upsert(
          _eventType(
            id: 'et-$i',
            name: 'Event $i',
            createdAt: DateTime(2026, 1, i),
          ),
        );
      }

      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const HomeScreen()),
        height: 1000,
        scaffold: false,
      );

      await expectGolden(tester, 'home_five_cards');
    });

    testWidgets('home_with_calendar_icon', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.calendars = [
        ...testDeps.calendar.calendars,
        const CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false),
      ];

      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const HomeScreen()),
        scaffold: false,
      );

      await expectGolden(tester, 'home_with_calendar_icon');
    });
  });
}
