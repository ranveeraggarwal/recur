import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/booking_repository.dart';
import 'package:recur/data/event_type_repository.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/data/models/booking.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/data/settings_repository.dart';
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
    preferredWindows: [TimeWindow(startMinutes: 480, endMinutes: 1080)],
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

/// Adds a booking and tells the fake calendar its event is still there, so
/// Home does not prune the booking as one whose event was deleted.
Future<void> _addBooking(TestDeps testDeps, Booking booking) async {
  await testDeps.deps.bookings.add(booking);
  testDeps.calendar.knownEventIds.add(booking.calendarEventId);
}

/// A [LocalStore] whose reads only finish after [delay], so a test can pump
/// a frame while Home is still part-way through a reload. Everything in the
/// fake stack otherwise resolves inside one microtask drain, which never
/// leaves an in-flight load visible to `pump()`.
class _SlowStore implements LocalStore {
  _SlowStore(this._inner);

  final LocalStore _inner;

  Duration delay = Duration.zero;

  @override
  Future<String?> read(String key) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return _inner.read(key);
  }

  @override
  Future<void> write(String key, String json) => _inner.write(key, json);

  @override
  Future<void> delete(String key) => _inner.delete(key);
}

/// [testDeps] with its repositories moved onto [store], so a test can slow
/// the reads down mid-test.
AppDependencies _depsOnStore(TestDeps testDeps, LocalStore store) {
  return AppDependencies(
    clock: testDeps.clock,
    ids: testDeps.deps.ids,
    eventTypes: LocalEventTypeRepository(store),
    bookings: LocalBookingRepository(store),
    settings: LocalSettingsRepository(store),
    calendar: testDeps.calendar,
    places: testDeps.places,
  );
}

/// Pumps Home at [goldenWidth] with [textScale] applied on top of the view's
/// own [MediaQueryData], collecting everything reported to
/// [FlutterError.onError] while it lays out and paints.
Future<List<FlutterErrorDetails>> _pumpHomeAtTextScale(
  WidgetTester tester,
  TestDeps testDeps,
  double textScale,
) async {
  tester.view.physicalSize = const Size(goldenWidth, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = errors.add;

  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: const HomeScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  FlutterError.onError = previousOnError;
  return errors;
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
      await _addBooking(
        testDeps,
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
    await _addBooking(
      testDeps,
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

  testWidgets('requests calendar access on load when not yet determined', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.access = CalendarAccess.notDetermined;
    testDeps.calendar.accessAfterRequest = CalendarAccess.granted;

    await _pumpHome(tester, testDeps);

    expect(testDeps.calendar.requestAccessCalls, 1);
  });

  testWidgets(
    'does not request calendar access again once already determined',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.access = CalendarAccess.denied;

      await _pumpHome(tester, testDeps);

      expect(testDeps.calendar.requestAccessCalls, 0);
    },
  );

  testWidgets('no calendar icon with only one writable calendar', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await _pumpHome(tester, testDeps);
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
  });

  testWidgets('a booking whose calendar event was deleted stops counting', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session'),
    );
    // Seeded without telling the fake calendar about the event, which is
    // what a booking whose event the user deleted looks like.
    await testDeps.deps.bookings.add(
      _booking(
        id: 'b-1',
        eventTypeId: 'et-1',
        start: DateTime(2026, 8, 17, 10),
      ),
    );

    await _pumpHome(tester, testDeps);

    final card = tester.widget<EventCard>(find.byType(EventCard));
    expect(card.lastBookedText, 'Not booked yet');
    expect(await testDeps.deps.bookings.getForEventType('et-1'), isEmpty);
  });

  testWidgets('bookings are kept when the calendar cannot be read', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.access = CalendarAccess.denied;
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session'),
    );
    await testDeps.deps.bookings.add(
      _booking(
        id: 'b-1',
        eventTypeId: 'et-1',
        start: DateTime(2026, 8, 17, 10),
      ),
    );

    await _pumpHome(tester, testDeps);

    final card = tester.widget<EventCard>(find.byType(EventCard));
    expect(card.lastBookedText, 'Last booked 3 weeks ago');
    expect(await testDeps.deps.bookings.getForEventType('et-1'), hasLength(1));
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

  testWidgets('a reload keeps the cards on screen instead of flashing empty', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    final store = _SlowStore(testDeps.store);
    final deps = _depsOnStore(testDeps, store);
    await deps.eventTypes.upsert(
      _eventType(
        id: 'et-1',
        name: 'PT session',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await deps.eventTypes.upsert(
      _eventType(id: 'et-2', name: 'Physio', createdAt: DateTime(2026, 1, 2)),
    );

    await tester.pumpWidget(
      AppScope(
        deps: deps,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventCard), findsNWidgets(2));

    await tester.tap(find.byType(EventCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Pick a slot'), findsOneWidget);

    // From here every read takes longer than a frame, so the reload Home
    // starts when Booking pops is still running when the next frame is
    // drawn.
    store.delay = const Duration(milliseconds: 200);

    await tester.pageBack();
    await tester.pump();
    expect(find.byType(EventCard), findsNWidgets(2));

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EventCard), findsNWidgets(2));

    store.delay = Duration.zero;
    await tester.pumpAndSettle();
    expect(find.byType(EventCard), findsNWidgets(2));
  });

  testWidgets('reloads when the app is resumed and Home is the current route', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session'),
    );
    await _addBooking(
      testDeps,
      _booking(
        id: 'b-1',
        eventTypeId: 'et-1',
        start: DateTime(2026, 9, 10, 10),
      ),
    );

    await _pumpHome(tester, testDeps);
    expect(
      tester.widget<EventCard>(find.byType(EventCard)).lastBookedText,
      'Booked for Thu 10 Sep',
    );

    // The user deleted the event in the calendar app while Recur was away.
    testDeps.calendar.knownEventIds.remove('evt-b-1');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      tester.widget<EventCard>(find.byType(EventCard)).lastBookedText,
      'Not booked yet',
    );
  });

  testWidgets('does not reload Home when it is not the current route', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session'),
    );
    await _addBooking(
      testDeps,
      _booking(
        id: 'b-1',
        eventTypeId: 'et-1',
        start: DateTime(2026, 9, 10, 10),
      ),
    );
    await _pumpHome(tester, testDeps);

    await tester.tap(find.byType(EventCard));
    await tester.pumpAndSettle();
    expect(find.text('Pick a slot'), findsOneWidget);

    testDeps.calendar.knownEventIds.remove('evt-b-1');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Home is underneath Booking, so nothing was pruned yet.
    expect(await testDeps.deps.bookings.getForEventType('et-1'), hasLength(1));
  });

  testWidgets('cards do not overflow at text scale 1.3', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(
        id: 'et-1',
        name: 'Physiotherapy with Anna at the clinic',
        location: 'Kungsholmen',
      ),
    );

    final errors = await _pumpHomeAtTextScale(tester, testDeps, 1.3);

    expect(find.byType(EventCard), findsOneWidget);
    expect(
      errors.where((e) => e.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });

  testWidgets('cards do not overflow at text scale 1.5', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(
        id: 'et-1',
        name: 'Physiotherapy with Anna at the clinic',
        location: 'Kungsholmen',
      ),
    );

    final errors = await _pumpHomeAtTextScale(tester, testDeps, 1.5);

    expect(find.byType(EventCard), findsOneWidget);
    expect(
      errors.where((e) => e.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });

  testWidgets('shows a read error, keeping the app bar and the FAB', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.store.write('event_types', 'not json');

    await _pumpHome(tester, testDeps);

    expect(find.text("Couldn't read your cards."), findsOneWidget);
    expect(find.text('Restart Recur to try again.'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Recur'), findsOneWidget);
    expect(find.byType(RecurFab), findsOneWidget);
  });

  testWidgets('renders without a calendar list when access is denied', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.access = CalendarAccess.denied;
    testDeps.calendar.calendars = [
      ...testDeps.calendar.calendars,
      const CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false),
    ];
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session'),
    );

    await _pumpHome(tester, testDeps);

    expect(find.byType(EventCard), findsOneWidget);
    // The count stayed at 0 because the calendars were never listed.
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
  });

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
      await _addBooking(
        testDeps,
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
