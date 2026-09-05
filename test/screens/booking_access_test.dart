import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/booking/booking_screen.dart';
import 'package:recur/widgets/confirm_button.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

EventType _ptSession() {
  return EventType(
    id: 'et-1',
    name: 'PT session',
    durationMinutes: 60,
    preferredWeekdays: const {1, 2, 3, 4, 5},
    preferredWindows: [TimeWindow(startMinutes: 480, endMinutes: 1080)],
    createdAt: DateTime(2020, 1, 1),
  );
}

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

  testWidgets('not-determined access shows the ask copy and button', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    testDeps.calendar.access = CalendarAccess.notDetermined;
    await _pumpBooking(tester, testDeps);

    expect(
      find.text('Recur needs calendar access to show your week.'),
      findsOneWidget,
    );
    expect(find.text('Allow calendar access'), findsOneWidget);
    expect(find.text('Pick a slot'), findsNothing);

    await tester.tap(find.text('Allow calendar access'));
    await tester.pumpAndSettle();

    expect(testDeps.calendar.requestAccessCalls, 1);
    expect(find.text('Pick a slot'), findsOneWidget);
  });

  testWidgets('denied access shows the settings copy and button', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    testDeps.calendar.access = CalendarAccess.denied;
    await _pumpBooking(tester, testDeps);

    expect(find.text('Calendar access is off for Recur.'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(testDeps.calendar.openSystemSettingsCalls, 1);
  });

  testWidgets(
    'granted access with no writable calendar shows its copy and no button',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      testDeps.calendar.access = CalendarAccess.granted;
      testDeps.calendar.calendars = [];
      await _pumpBooking(tester, testDeps);

      expect(find.text('No writable calendar found.'), findsOneWidget);
      expect(find.byType(ConfirmButton), findsNothing);
      expect(find.text('Allow calendar access'), findsNothing);
      expect(find.text('Open settings'), findsNothing);
    },
  );

  group('goldens', () {
    testWidgets('booking_access_ask', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      testDeps.calendar.access = CalendarAccess.notDetermined;

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 700,
        scaffold: false,
      );

      await expectGolden(tester, 'booking_access_ask');
    });

    testWidgets('booking_access_denied', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      testDeps.calendar.access = CalendarAccess.denied;

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 700,
        scaffold: false,
      );

      await expectGolden(tester, 'booking_access_denied');
    });

    testWidgets('booking_no_calendar', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      testDeps.calendar.access = CalendarAccess.granted;
      testDeps.calendar.calendars = [];

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 700,
        scaffold: false,
      );

      await expectGolden(tester, 'booking_no_calendar');
    });
  });
}
