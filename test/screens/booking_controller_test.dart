import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/local_date.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/booking/booking_controller.dart';
import 'package:recur/suggestions/slot_grid.dart';

import '../helpers/fakes.dart';

/// `PT session`, 60 min, preferred Tue/Thu 09:00-12:00 (540-720).
EventType _ptSession() {
  return EventType(
    id: 'et-1',
    name: 'PT session',
    durationMinutes: 60,
    preferredWeekdays: const {2, 4},
    preferredWindows: [TimeWindow(startMinutes: 540, endMinutes: 720)],
    createdAt: DateTime(2020, 1, 1),
  );
}

void main() {
  // FixedClock defaults to Mon 2026-09-07 09:00.
  final today = LocalDate(2026, 9, 7);

  group('init', () {
    test('builds seven grids of 32 slots and defaults to today', () async {
      final testDeps = buildTestDeps();
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );

      await controller.init();

      expect(controller.today, today);
      expect(controller.weekMonday, today);
      expect(controller.selectedDate, today);
      expect(controller.grids, hasLength(7));
      for (final slots in controller.grids.values) {
        expect(slots, hasLength(32));
      }
      expect(controller.access, CalendarAccess.granted);
      expect(controller.hasWritableCalendar, isTrue);
    });

    test('Tuesday and Thursday pills have hasSuggestions', () async {
      final testDeps = buildTestDeps();
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );

      await controller.init();

      final tuesday = today.addDays(1);
      final thursday = today.addDays(3);
      final wednesday = today.addDays(2);

      expect(
        controller.grids[tuesday]!.any((s) => s.state == SlotState.highlighted),
        isTrue,
      );
      expect(
        controller.grids[thursday]!.any(
          (s) => s.state == SlotState.highlighted,
        ),
        isTrue,
      );
      expect(
        controller.grids[wednesday]!.any(
          (s) => s.state == SlotState.highlighted,
        ),
        isFalse,
      );
    });

    test('a busy interval blocks the right slots', () async {
      final testDeps = buildTestDeps();
      final tuesday = today.addDays(1);
      testDeps.calendar.busy.add(
        BusyInterval(
          start: tuesday.at(600), // 10:00
          end: tuesday.at(660), // 11:00
          title: 'Dentist',
        ),
      );

      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();

      final slots = controller.grids[tuesday]!;
      final at930 = slots.firstWhere((s) => s.startMinutes == 570);
      final at1000 = slots.firstWhere((s) => s.startMinutes == 600);
      final at1030 = slots.firstWhere((s) => s.startMinutes == 630);
      final at900 = slots.firstWhere((s) => s.startMinutes == 540);
      final at1100 = slots.firstWhere((s) => s.startMinutes == 660);

      expect(at930.state, SlotState.blocked);
      expect(at930.blockReason, BlockReason.doesNotFit);
      expect(at930.blockingTitle, isNull);
      expect(at1000.state, SlotState.blocked);
      expect(at1000.blockReason, BlockReason.conflict);
      expect(at1000.blockingTitle, 'Dentist');
      expect(at1030.state, SlotState.blocked);
      expect(at1030.blockReason, BlockReason.conflict);
      expect(at1030.blockingTitle, 'Dentist');
      expect(at900.state, isNot(SlotState.blocked));
      expect(at1100.state, isNot(SlotState.blocked));
    });
  });

  group('selectDate and toggleSlot', () {
    test('selectDate switches the selected day', () async {
      final testDeps = buildTestDeps();
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();

      final tuesday = today.addDays(1);
      controller.selectDate(tuesday);

      expect(controller.selectedDate, tuesday);
    });

    test('toggleSlot selects then clears on a second tap', () async {
      final testDeps = buildTestDeps();
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();

      final slot = controller.grids[today]!.firstWhere(
        (s) => s.state != SlotState.blocked,
      );

      controller.toggleSlot(slot);
      expect(controller.selectedSlot, slot);

      controller.toggleSlot(slot);
      expect(controller.selectedSlot, isNull);
    });

    test('selecting a slot on another day clears the previous one', () async {
      final testDeps = buildTestDeps();
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();

      final tuesday = today.addDays(1);
      final slotToday = controller.grids[today]!.firstWhere(
        (s) => s.state != SlotState.blocked,
      );
      final slotTuesday = controller.grids[tuesday]!.firstWhere(
        (s) => s.state != SlotState.blocked,
      );

      controller.toggleSlot(slotToday);
      expect(controller.selectedSlot, slotToday);

      controller.toggleSlot(slotTuesday);
      expect(controller.selectedSlot, slotTuesday);
      expect(controller.selectedDate, tuesday);
    });
  });

  group('access', () {
    test('with access denied, init does not read the calendar list', () async {
      final testDeps = buildTestDeps();
      testDeps.calendar.access = CalendarAccess.denied;
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );

      await controller.init();

      // Listing calendars needs the permission too, so it must wait for
      // the granted branch; the screen shows its access state instead.
      expect(controller.access, CalendarAccess.denied);
      expect(controller.hasWritableCalendar, isFalse);
      expect(controller.writableCalendarCount, 0);
      expect(controller.grids, isEmpty);
    });

    test('requesting access reads the calendar list and the week', () async {
      final testDeps = buildTestDeps();
      testDeps.calendar.access = CalendarAccess.notDetermined;
      testDeps.calendar.accessAfterRequest = CalendarAccess.granted;
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();
      expect(controller.hasWritableCalendar, isFalse);

      await controller.requestAccess();

      expect(controller.hasWritableCalendar, isTrue);
      expect(controller.grids, hasLength(7));
    });
  });

  group('a slot that has passed', () {
    test('confirm writes nothing, drops the selection, and rebuilds', () async {
      final testDeps = buildTestDeps(now: DateTime(2026, 9, 7, 9, 58));
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();
      final tenAm = controller.grids[today]!.firstWhere(
        (s) => s.startMinutes == 600,
      );
      expect(tenAm.state, isNot(SlotState.blocked));
      controller.toggleSlot(tenAm);

      testDeps.clock.advance(const Duration(minutes: 25));

      await expectLater(
        () => controller.confirm(calendarId: 'cal-1'),
        throwsA(isA<StateError>()),
      );

      expect(testDeps.calendar.created, isEmpty);
      expect(await testDeps.deps.bookings.getForEventType('et-1'), isEmpty);
      expect(controller.selectedSlot, isNull);
      final after = controller.grids[today]!.firstWhere(
        (s) => s.startMinutes == 600,
      );
      expect(after.state, SlotState.blocked);
      expect(after.blockReason, BlockReason.past);
    });
  });

  group('refresh', () {
    test('recomputes today and rebuilds the week over midnight', () async {
      final testDeps = buildTestDeps(now: DateTime(2026, 9, 7, 23, 59));
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();
      final tuesday = today.addDays(1);
      controller.selectDate(tuesday);
      expect(controller.today, today);

      testDeps.clock.advance(const Duration(minutes: 2));
      await controller.refresh();

      expect(controller.today, tuesday);
      expect(
        controller.grids[today]!.every(
          (s) => s.blockReason == BlockReason.past,
        ),
        isTrue,
      );
      expect(controller.selectedDate, tuesday);
    });

    test('selectDate refreshes only once the day has rolled over', () async {
      final testDeps = buildTestDeps(now: DateTime(2026, 9, 7, 23, 59));
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();
      final queriesAfterInit = testDeps.calendar.busyQueries.length;

      controller.selectDate(today.addDays(2));
      await pumpEventQueue();

      // Same day still: no calendar fetch per tap.
      expect(testDeps.calendar.busyQueries, hasLength(queriesAfterInit));
      expect(controller.today, today);

      testDeps.clock.advance(const Duration(minutes: 2));
      controller.selectDate(today.addDays(3));
      await pumpEventQueue();

      expect(testDeps.calendar.busyQueries.length, queriesAfterInit + 1);
      expect(controller.today, today.addDays(1));
    });

    test('refresh without access moves today but reads nothing', () async {
      final testDeps = buildTestDeps(now: DateTime(2026, 9, 7, 23, 59));
      testDeps.calendar.access = CalendarAccess.denied;
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();

      testDeps.clock.advance(const Duration(minutes: 2));
      await controller.refresh();

      expect(controller.today, today.addDays(1));
      expect(testDeps.calendar.busyQueries, isEmpty);
    });
  });

  group('showWeek', () {
    test('fetches the queried range for the new week', () async {
      final testDeps = buildTestDeps();
      final controller = BookingController(
        eventType: _ptSession(),
        deps: testDeps.deps,
      );
      await controller.init();

      final nextMonday = today.addDays(7);
      await controller.showWeek(nextMonday);

      final lastQuery = testDeps.calendar.busyQueries.last;
      expect(lastQuery.from, nextMonday.at(0));
      expect(lastQuery.to, nextMonday.addDays(7).at(0));
      expect(controller.weekMonday, nextMonday);
    });

    test(
      'init lands on the current week (the back chevron disables '
      'further navigation at the screen level; see the Decisions table)',
      () async {
        final testDeps = buildTestDeps();
        final controller = BookingController(
          eventType: _ptSession(),
          deps: testDeps.deps,
        );
        await controller.init();

        expect(controller.weekMonday, today.mondayOfWeek);
      },
    );

    test(
      'selection is cleared when the selected date leaves the displayed week',
      () async {
        final testDeps = buildTestDeps();
        final controller = BookingController(
          eventType: _ptSession(),
          deps: testDeps.deps,
        );
        await controller.init();

        final slot = controller.grids[today]!.firstWhere(
          (s) => s.state != SlotState.blocked,
        );
        controller.toggleSlot(slot);
        expect(controller.selectedSlot, isNotNull);

        await controller.showWeek(today.addDays(7));

        expect(controller.selectedSlot, isNull);
        expect(controller.selectedDate, today.addDays(7));
      },
    );
  });
}
