import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/booking/booking_screen.dart';
import 'package:recur/widgets/confirm_button.dart';

import '../helpers/fakes.dart';

/// `PT session`, 60 min, Kungsholmen, no notes, preferred Tue/Thu 09:00-12:00.
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

/// Pushes [BookingScreen] on top of a root screen with an `open` button, so
/// tests can observe `Navigator.pop` back to it.
Future<void> _pumpBookingPushed(WidgetTester tester, TestDeps testDeps) async {
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
                    builder: (_) => const BookingScreen(eventTypeId: 'et-1'),
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

Future<void> _selectSlot(WidgetTester tester) async {
  // Monday (today) has no preference window, so 09:30 (after "now" 09:00)
  // is a plain available slot.
  await tester.tap(find.text('09:30'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirm writes exactly one event and logs one booking with the '
      'returned calendar event id', (WidgetTester tester) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBookingPushed(tester, testDeps);
    await _selectSlot(tester);

    await tester.tap(find.widgetWithText(ConfirmButton, 'Confirm'));
    await tester.pumpAndSettle();
    // Auto-dismiss the confirmation sheet.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(testDeps.calendar.created, hasLength(1));
    final created = testDeps.calendar.created.single;
    expect(created.calendarId, 'cal-1');
    expect(created.title, 'PT session');
    expect(created.location, 'Kungsholmen');
    expect(created.start, DateTime(2026, 9, 7, 9, 30));
    expect(created.end, DateTime(2026, 9, 7, 10, 30));

    final bookings = await testDeps.deps.bookings.getForEventType('et-1');
    expect(bookings, hasLength(1));
    expect(bookings.single.calendarEventId, 'evt-1');
    expect(bookings.single.calendarId, 'cal-1');

    // The Confirmation sheet dismissed and popped back to the root.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'a calendar-write failure shows the snack bar, logs nothing, keeps the selection',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      testDeps.calendar.failNextCreateWith = 'boom';
      await _pumpBookingPushed(tester, testDeps);
      await _selectSlot(tester);

      await tester.tap(find.widgetWithText(ConfirmButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't add to calendar."), findsOneWidget);
      expect(testDeps.calendar.created, isEmpty);
      expect(await testDeps.deps.bookings.getForEventType('et-1'), isEmpty);
      // Still on the Booking screen, with the slot's summary shown.
      expect(find.text('Mon 7 Sep, 09:30 to 10:30'), findsOneWidget);
    },
  );

  testWidgets(
    'with two calendars and no prior choice, the picker opens before confirm',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      testDeps.calendar.calendars = [
        ...testDeps.calendar.calendars,
        const CalendarInfo(id: 'cal-2', name: 'Work', isPrimary: false),
      ];
      await _pumpBookingPushed(tester, testDeps);
      await _selectSlot(tester);

      await tester.tap(find.widgetWithText(ConfirmButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Write bookings to'), findsOneWidget);
      expect(testDeps.calendar.created, isEmpty);

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(testDeps.calendar.created, hasLength(1));
      expect(testDeps.calendar.created.single.calendarId, 'cal-2');
      expect((await testDeps.deps.settings.get()).selectedCalendarId, 'cal-2');
    },
  );

  testWidgets('with one calendar, confirm proceeds without a picker', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBookingPushed(tester, testDeps);
    await _selectSlot(tester);

    await tester.tap(find.widgetWithText(ConfirmButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Write bookings to'), findsNothing);
    expect(find.text('Booked'), findsOneWidget);
  });

  testWidgets('a slot that started while the screen sat open is refused', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBookingPushed(tester, testDeps);
    await _selectSlot(tester);

    // 09:00 becomes 09:45: the picked 09:30 slot has already started.
    testDeps.clock.advance(const Duration(minutes: 45));

    await tester.tap(find.widgetWithText(ConfirmButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('That slot has passed. Pick another.'), findsOneWidget);
    expect(testDeps.calendar.created, isEmpty);
    expect(await testDeps.deps.bookings.getForEventType('et-1'), isEmpty);
    // The selection is gone and the row now reads as past.
    expect(find.text('Pick a slot'), findsOneWidget);
    expect(find.text('Past'), findsWidgets);
  });

  testWidgets(
    'the confirmation sheet auto-dismisses after 2 seconds and pops to Home',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      await _pumpBookingPushed(tester, testDeps);
      await _selectSlot(tester);

      await tester.tap(find.widgetWithText(ConfirmButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('open'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Booked'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );
}
