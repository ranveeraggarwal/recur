import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/calendar/fake_calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/event_type_repository.dart';
import 'package:recur/data/local_store.dart';
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
  String? notes,
  DateTime? createdAt,
  String? code,
}) {
  return EventType(
    id: id,
    name: name,
    durationMinutes: durationMinutes,
    location: location,
    notes: notes,
    preferredWeekdays: const {1, 2, 3, 4, 5},
    preferredWindows: [TimeWindow(startMinutes: 480, endMinutes: 1080)],
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    code: code,
  );
}

/// Puts an hour-long event in the fake calendar carrying the marker for
/// card [code], as if the user had saved one Recur opened.
void _addMarkedEvent(
  TestDeps testDeps, {
  required String code,
  required DateTime start,
  String occurrence = '001',
}) {
  testDeps.calendar.events.add(
    CalendarEvent(
      id: 'evt-$code$occurrence',
      calendarId: 'cal-1',
      title: 'PT session',
      start: start,
      end: start.add(const Duration(hours: 1)),
      isAllDay: false,
      notes: 'Booked with Recur - rc$code$occurrence',
    ),
  );
}

/// A [FakeCalendarGateway] whose reads only finish after [delay], so a
/// test can see the scan part-way through.
class _SlowCalendar extends FakeCalendarGateway {
  Duration delay = Duration.zero;

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return super.listEvents(from: from, to: to);
  }
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
    random: testDeps.deps.random,
    eventTypes: LocalEventTypeRepository(store),
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
          code: 'ab',
        ),
      );
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-2',
          name: 'Physio',
          durationMinutes: 45,
          createdAt: DateTime(2026, 1, 2),
          code: 'cd',
        ),
      );
      _addMarkedEvent(testDeps, code: 'ab', start: DateTime(2026, 8, 17, 10));

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

  testWidgets('an upcoming booking shows Booked for ... in primary', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
    );
    _addMarkedEvent(testDeps, code: 'ab', start: DateTime(2026, 8, 17, 10));
    _addMarkedEvent(
      testDeps,
      code: 'ab',
      start: DateTime(2026, 9, 10, 10),
      occurrence: '002',
    );

    await _pumpHome(tester, testDeps);

    final card = tester.widget<EventCard>(find.byType(EventCard));
    expect(card.lastBookedText, 'Booked for Thu 10 Sep');
    expect(card.lastBookedIsFuture, isTrue);
  });

  testWidgets('an event without the marker does not count', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
    );
    testDeps.calendar.events.add(
      CalendarEvent(
        id: 'evt-1',
        calendarId: 'cal-1',
        title: 'PT session',
        start: DateTime(2026, 8, 17, 10),
        end: DateTime(2026, 8, 17, 11),
        isAllDay: false,
        notes: 'Bring a towel',
      ),
    );

    await _pumpHome(tester, testDeps);

    final card = tester.widget<EventCard>(find.byType(EventCard));
    expect(card.lastBookedText, 'Not booked yet');
  });

  testWidgets('gives a card without a code one, and saves it', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
    );
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-2', name: 'Physio', createdAt: DateTime(2026, 1, 2)),
    );

    await _pumpHome(tester, testDeps);

    final saved = await testDeps.deps.eventTypes.getAll();
    expect(saved[0].code, 'ab');
    expect(saved[1].code, matches(RegExp(r'^[0-9a-z]{2}$')));
    expect(saved[1].code, isNot('ab'));
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

  testWidgets(
    'without access, shows the access message and no last-booked line',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.access = CalendarAccess.denied;
      await testDeps.deps.eventTypes.upsert(
        _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
      );
      _addMarkedEvent(testDeps, code: 'ab', start: DateTime(2026, 8, 17, 10));

      await _pumpHome(tester, testDeps);

      expect(
        find.text('Recur needs calendar access to see what you have booked.'),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
      final card = tester.widget<EventCard>(find.byType(EventCard));
      expect(card.lastBookedText, '');

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(testDeps.calendar.openSystemSettingsCalls, 1);
    },
  );

  testWidgets('a refused first ask offers Allow calendar access', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.access = CalendarAccess.notDetermined;
    testDeps.calendar.accessAfterRequest = CalendarAccess.notDetermined;

    await _pumpHome(tester, testDeps);

    expect(
      find.text('Recur needs calendar access to see what you have booked.'),
      findsOneWidget,
    );
    testDeps.calendar.accessAfterRequest = CalendarAccess.granted;
    await tester.tap(find.text('Allow calendar access'));
    await tester.pumpAndSettle();

    expect(find.text('Allow calendar access'), findsNothing);
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

  testWidgets('long-press opens the Editor with the right id', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session'),
    );
    await _pumpHome(tester, testDeps);

    await tester.longPress(find.byType(EventCard));
    await tester.pumpAndSettle();
    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('PT session'), findsWidgets);
  });

  group('tapping a card', () {
    testWidgets('opens the calendar app tomorrow, filled in, with a marker', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-1',
          name: 'PT session',
          location: 'Kungsholmen',
          notes: 'Bring a towel',
          code: 'ab',
        ),
      );
      await _pumpHome(tester, testDeps);

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();

      final opened = testDeps.calendar.opened.single;
      expect(opened.title, 'PT session');
      expect(opened.location, 'Kungsholmen');
      // Now is Monday 7 Sep at 09:00; the earliest suggestion is tomorrow.
      expect(opened.start, DateTime(2026, 9, 8, 8));
      expect(opened.end, DateTime(2026, 9, 8, 9));
      expect(
        opened.notes,
        matches(
          RegExp(r'^Bring a towel\n\nBooked with Recur - rcab[0-9a-z]{3}$'),
        ),
      );
    });

    testWidgets('skips past busy time', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(
        _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
      );
      testDeps.calendar.busy.add(
        BusyInterval(
          start: DateTime(2026, 9, 8, 8),
          end: DateTime(2026, 9, 8, 10),
          title: 'Dentist',
        ),
      );
      await _pumpHome(tester, testDeps);

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();

      expect(testDeps.calendar.opened.single.start, DateTime(2026, 9, 8, 10));
      expect(
        testDeps.calendar.opened.single.notes,
        matches(RegExp(r'^Booked with Recur - rcab[0-9a-z]{3}$')),
      );
    });

    testWidgets('works without calendar access, ignoring busy times', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.access = CalendarAccess.denied;
      await testDeps.deps.eventTypes.upsert(
        _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
      );
      await _pumpHome(tester, testDeps);

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();

      expect(testDeps.calendar.opened.single.start, DateTime(2026, 9, 8, 8));
      expect(testDeps.calendar.busyQueries, isEmpty);
    });

    testWidgets('says so when the calendar app cannot be opened', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(
        _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
      );
      testDeps.calendar.failNextOpenWith = 'No calendar app.';
      await _pumpHome(tester, testDeps);

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't open your calendar."), findsOneWidget);
    });

    testWidgets('an event saved in the calendar app shows up on resume', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(
        _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
      );
      await _pumpHome(tester, testDeps);
      expect(
        tester.widget<EventCard>(find.byType(EventCard)).lastBookedText,
        'Not booked yet',
      );

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();
      testDeps.calendar.saveOpened();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        tester.widget<EventCard>(find.byType(EventCard)).lastBookedText,
        'Booked for Tue 8 Sep',
      );
    });
  });

  testWidgets('shows the progress bar only while the scan runs', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    final calendar = _SlowCalendar()..delay = const Duration(milliseconds: 50);
    final deps = AppDependencies(
      clock: testDeps.clock,
      ids: testDeps.deps.ids,
      random: testDeps.deps.random,
      eventTypes: testDeps.deps.eventTypes,
      calendar: calendar,
      places: testDeps.places,
    );
    await deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
    );

    await tester.pumpWidget(
      AppScope(
        deps: deps,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<EventCard>(find.byType(EventCard)).lastBookedText, '');

    // The slow reads wait on timers, which pumpAndSettle alone does not
    // advance.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.widget<EventCard>(find.byType(EventCard)).lastBookedText,
      'Not booked yet',
    );
  });

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
        code: 'ab',
      ),
    );
    await deps.eventTypes.upsert(
      _eventType(
        id: 'et-2',
        name: 'Physio',
        createdAt: DateTime(2026, 1, 2),
        code: 'cd',
      ),
    );

    await tester.pumpWidget(
      AppScope(
        deps: deps,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventCard), findsNWidgets(2));

    // From here every read takes longer than a frame, so the reload a
    // resume starts is still running when the next frame is drawn.
    store.delay = const Duration(milliseconds: 200);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(EventCard), findsNWidgets(2));

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EventCard), findsNWidgets(2));

    store.delay = Duration.zero;
    await tester.pumpAndSettle();
    expect(find.byType(EventCard), findsNWidgets(2));
  });

  testWidgets('does not rescan when Home is not the current route', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(
      _eventType(id: 'et-1', name: 'PT session', code: 'ab'),
    );
    await _pumpHome(tester, testDeps);

    await tester.longPress(find.byType(EventCard));
    await tester.pumpAndSettle();
    expect(find.text('Edit event'), findsOneWidget);

    final reads = testDeps.calendar.listQueries.length;
    // The Editor listens for lifecycle changes too, and only accepts the
    // real order of states.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(testDeps.calendar.listQueries, hasLength(reads));
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
          code: 'ab',
        ),
      );
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-2',
          name: 'Physio',
          durationMinutes: 45,
          createdAt: DateTime(2026, 1, 2),
          code: 'cd',
        ),
      );
      _addMarkedEvent(testDeps, code: 'ab', start: DateTime(2026, 8, 17, 10));

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

    testWidgets('home_access_denied', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      testDeps.calendar.access = CalendarAccess.denied;
      await testDeps.deps.eventTypes.upsert(
        _eventType(
          id: 'et-1',
          name: 'PT session',
          location: 'Kungsholmen',
          code: 'ab',
        ),
      );

      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const HomeScreen()),
        scaffold: false,
      );

      await expectGolden(tester, 'home_access_denied');
    });
  });
}
