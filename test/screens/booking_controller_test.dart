import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/local_date.dart';
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
    preferredStartMinutes: 540,
    preferredEndMinutes: 720,
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
      expect(at930.blockReason, BlockReason.conflict);
      expect(at930.blockingTitle, 'Dentist');
      expect(at1000.state, SlotState.blocked);
      expect(at1030.state, SlotState.blocked);
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
