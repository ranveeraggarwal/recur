import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/local_date.dart';
import 'package:recur/suggestions/slot_grid.dart';
import 'package:recur/suggestions/suggestion_window.dart';

final bool _isStockholm =
    DateTime(2026, 3, 29, 1).timeZoneOffset !=
        DateTime(2026, 3, 29, 4).timeZoneOffset &&
    DateTime(2026, 3, 29, 1).timeZoneOffset == const Duration(hours: 1);
const _needsStockholm = 'Run with TZ=Europe/Stockholm';

final _emptyWindow = SuggestionWindow(
  weekdays: const <int>{},
  startMinutes: 360,
  endMinutes: 1320,
);

void main() {
  group('buildSlotGrid', () {
    test('returns 32 slots from 06:00 to 21:30', () {
      final date = LocalDate(2026, 6, 15); // a Monday, far from now/busy.
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      expect(slots.length, 32);
      expect(slots.first.startMinutes, 360);
      expect(slots.last.startMinutes, 1290);
      for (var i = 0; i < slots.length; i++) {
        expect(slots[i].startMinutes, 360 + i * 30);
      }
    });

    test('all slots past when now is after 22:00', () {
      final date = LocalDate(2026, 6, 15);
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: const [],
        now: date.at(1320), // 22:00, after every slot start.
      );
      for (final s in slots) {
        expect(s.state, SlotState.blocked);
        expect(s.blockReason, BlockReason.past);
      }
    });

    test('slot starting exactly at now is past', () {
      final date = LocalDate(2026, 6, 15);
      final now = date.at(600); // 10:00
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: const [],
        now: now,
      );
      final slot = slots.firstWhere((s) => s.startMinutes == 600);
      expect(slot.state, SlotState.blocked);
      expect(slot.blockReason, BlockReason.past);
    });

    test('slot starting one minute after now is not past', () {
      final date = LocalDate(2026, 6, 15);
      final now = date.at(600).subtract(const Duration(minutes: 1));
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: const [],
        now: now,
      );
      final slot = slots.firstWhere((s) => s.startMinutes == 600);
      expect(slot.blockReason, isNot(BlockReason.past));
    });

    test('outside hours blocks the tail for a 90-minute duration', () {
      final date = LocalDate(2026, 6, 15);
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 90,
        window: _emptyWindow,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      // Per the spec formula (endMinutes > 1320 => outsideHours), a 90-minute
      // appointment starting at 20:30 ends exactly at 22:00 (1320) and fits;
      // only 21:00 and 21:30 push past the boundary. See the Decisions table
      // in docs/architecture.md for this reconciliation with the issue's
      // prose example.
      for (final startMinutes in [1260, 1290]) {
        final slot = slots.firstWhere((s) => s.startMinutes == startMinutes);
        expect(
          slot.blockReason,
          BlockReason.outsideHours,
          reason: 'slot at $startMinutes should be outsideHours',
        );
      }
      for (final startMinutes in [1200, 1230]) {
        final slot = slots.firstWhere((s) => s.startMinutes == startMinutes);
        expect(
          slot.blockReason,
          isNot(BlockReason.outsideHours),
          reason: 'slot at $startMinutes should fit exactly within hours',
        );
      }
    });

    test('conflict blocks every slot whose appointment overlaps', () {
      final date = LocalDate(2026, 6, 15);
      final busy = [
        BusyInterval(start: date.at(600), end: date.at(660), title: 'Standup'),
      ];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 60,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      for (final startMinutes in [570, 600, 630]) {
        final slot = slots.firstWhere((s) => s.startMinutes == startMinutes);
        expect(
          slot.blockReason,
          BlockReason.conflict,
          reason: 'slot at $startMinutes should conflict',
        );
      }
      final slot540 = slots.firstWhere((s) => s.startMinutes == 540); // 09:00
      final slot660 = slots.firstWhere((s) => s.startMinutes == 660); // 11:00
      expect(slot540.state, isNot(SlotState.blocked));
      expect(slot660.state, isNot(SlotState.blocked));
    });

    test('event ending at slot start does not block', () {
      final date = LocalDate(2026, 6, 15);
      final busy = [BusyInterval(start: date.at(540), end: date.at(600))];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      final slot = slots.firstWhere((s) => s.startMinutes == 600);
      expect(slot.state, isNot(SlotState.blocked));
    });

    test('event starting at appointment end does not block', () {
      final date = LocalDate(2026, 6, 15);
      final busy = [BusyInterval(start: date.at(660), end: date.at(720))];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 60,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      final slot = slots.firstWhere(
        (s) => s.startMinutes == 600,
      ); // 10:00-11:00
      expect(slot.state, isNot(SlotState.blocked));
    });

    test('blockingTitle is the earliest overlapping event\'s title, null when untitled', () {
      final date = LocalDate(2026, 6, 15);
      final busy = [
        BusyInterval(start: date.at(630), end: date.at(660), title: 'Later'),
        BusyInterval(start: date.at(600), end: date.at(630)),
      ];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 90,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      // 09:30-11:00 overlaps both busy intervals; the earlier one (10:00) has
      // no title.
      final slot = slots.firstWhere((s) => s.startMinutes == 570);
      expect(slot.blockReason, BlockReason.conflict);
      expect(slot.blockingTitle, isNull);
    });

    test('highlighted only inside the window and only on window weekdays', () {
      final monday = LocalDate(2026, 6, 15); // Monday
      final tuesday = LocalDate(2026, 6, 16); // Tuesday
      final window = SuggestionWindow(
        weekdays: const {1}, // Monday only
        startMinutes: 540, // 09:00
        endMinutes: 720, // 12:00
      );
      final mondaySlots = buildSlotGrid(
        date: monday,
        durationMinutes: 30,
        window: window,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      final tuesdaySlots = buildSlotGrid(
        date: tuesday,
        durationMinutes: 30,
        window: window,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      final mondayInWindow = mondaySlots.firstWhere(
        (s) => s.startMinutes == 570,
      );
      expect(mondayInWindow.state, SlotState.highlighted);
      final mondayOutsideWindow = mondaySlots.firstWhere(
        (s) => s.startMinutes == 420,
      );
      expect(mondayOutsideWindow.state, SlotState.available);
      final tuesdayInWindow = tuesdaySlots.firstWhere(
        (s) => s.startMinutes == 570,
      );
      expect(tuesdayInWindow.state, SlotState.available);
    });

    test('highlight requires the full duration to fit', () {
      final date = LocalDate(2026, 6, 15); // Monday
      final window = SuggestionWindow(
        weekdays: const {1},
        startMinutes: 540, // 09:00
        endMinutes: 660, // 11:00
      );
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 60,
        window: window,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      for (final startMinutes in [540, 570, 600]) {
        final slot = slots.firstWhere((s) => s.startMinutes == startMinutes);
        expect(
          slot.state,
          SlotState.highlighted,
          reason: 'slot at $startMinutes should be highlighted',
        );
      }
      final slot630 = slots.firstWhere(
        (s) => s.startMinutes == 630,
      ); // ends 730
      expect(slot630.state, isNot(SlotState.highlighted));
    });

    test('past beats highlighted', () {
      final date = LocalDate(2026, 6, 15); // Monday
      final window = SuggestionWindow(
        weekdays: const {1},
        startMinutes: 360,
        endMinutes: 1320,
      );
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: window,
        busy: const [],
        now: date.at(600), // exactly at 10:00 slot start.
      );
      final slot = slots.firstWhere((s) => s.startMinutes == 600);
      expect(slot.state, SlotState.blocked);
      expect(slot.blockReason, BlockReason.past);
    });

    test('conflict beats highlighted', () {
      final date = LocalDate(2026, 6, 15); // Monday
      final window = SuggestionWindow(
        weekdays: const {1},
        startMinutes: 360,
        endMinutes: 1320,
      );
      final busy = [BusyInterval(start: date.at(600), end: date.at(630))];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: window,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      final slot = slots.firstWhere((s) => s.startMinutes == 600);
      expect(slot.state, SlotState.blocked);
      expect(slot.blockReason, BlockReason.conflict);
    });

    test('outside hours beats highlighted', () {
      final date = LocalDate(2026, 6, 15); // Monday
      final window = SuggestionWindow(
        weekdays: const {1},
        startMinutes: 360,
        endMinutes: 1320,
      );
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 90,
        window: window,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      final slot = slots.firstWhere((s) => s.startMinutes == 1290);
      expect(slot.state, SlotState.blocked);
      expect(slot.blockReason, BlockReason.outsideHours);
    });

    test('all-day style interval passed in still blocks', () {
      final date = LocalDate(2026, 6, 15);
      final busy = [
        BusyInterval(start: date.at(0), end: date.addDays(1).at(0)),
      ];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      expect(slots.length, 32);
      for (final s in slots) {
        expect(s.state, SlotState.blocked);
        expect(s.blockReason, BlockReason.conflict);
      }
    });
  });

  group('Stockholm DST week', () {
    test('spring-forward Sunday 2026-03-29 has 32 slots with correct wall-clock labels', () {
      final date = LocalDate(2026, 3, 29);
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      expect(slots.length, 32);
      expect(slots.first.start, DateTime(2026, 3, 29, 6, 0));
      expect(slots.last.start, DateTime(2026, 3, 29, 21, 30));
      // The trap this design avoids: naive Duration addition from midnight
      // skips the spring-forward hour, landing on 07:00 instead of 06:00.
      expect(DateTime(2026, 3, 29, 0, 0).add(const Duration(hours: 6)).hour, 7);
    }, skip: _isStockholm ? false : _needsStockholm);

    test('spring-forward Sunday conflict at 10:00-11:00 blocks 09:30, 10:00, 10:30 for 60 min', () {
      final date = LocalDate(2026, 3, 29);
      final busy = [BusyInterval(start: date.at(600), end: date.at(660))];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 60,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      for (final startMinutes in [570, 600, 630]) {
        final slot = slots.firstWhere((s) => s.startMinutes == startMinutes);
        expect(slot.blockReason, BlockReason.conflict);
      }
    }, skip: _isStockholm ? false : _needsStockholm);

    test(
      'spring-forward Sunday slot end is start plus duration in wall-clock',
      () {
        final date = LocalDate(2026, 3, 29);
        final slots = buildSlotGrid(
          date: date,
          durationMinutes: 60,
          window: _emptyWindow,
          busy: const [],
          now: DateTime(2020, 1, 1),
        );
        final slot = slots.firstWhere((s) => s.startMinutes == 360);
        expect(slot.endMinutes, 420);
        expect(date.at(420), DateTime(2026, 3, 29, 7, 0));
        expect(date.at(420).difference(slot.start), const Duration(hours: 1));
      },
      skip: _isStockholm ? false : _needsStockholm,
    );

    test('fall-back Sunday 2026-10-25 has 32 slots with correct labels', () {
      final date = LocalDate(2026, 10, 25);
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: const [],
        now: DateTime(2020, 1, 1),
      );
      expect(slots.length, 32);
      expect(slots.first.start, DateTime(2026, 10, 25, 6, 0));
      expect(slots.last.start, DateTime(2026, 10, 25, 21, 30));
    }, skip: _isStockholm ? false : _needsStockholm);

    test('fall-back Sunday conflict blocks correctly', () {
      final date = LocalDate(2026, 10, 25);
      final busy = [BusyInterval(start: date.at(600), end: date.at(660))];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 60,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      for (final startMinutes in [570, 600, 630]) {
        final slot = slots.firstWhere((s) => s.startMinutes == startMinutes);
        expect(slot.blockReason, BlockReason.conflict);
      }
      final slot540 = slots.firstWhere((s) => s.startMinutes == 540);
      expect(slot540.state, isNot(SlotState.blocked));
    }, skip: _isStockholm ? false : _needsStockholm);

    test('week of 2026-03-23 to 2026-03-29 builds 7 grids of 32 slots and highlights '
        'Sunday 09:00 when window includes weekday 7', () {
      final window = SuggestionWindow(
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startMinutes: 540, // 09:00
        endMinutes: 1320,
      );
      var date = LocalDate(2026, 3, 23);
      final grids = <List<Slot>>[];
      for (var i = 0; i < 7; i++) {
        grids.add(
          buildSlotGrid(
            date: date,
            durationMinutes: 30,
            window: window,
            busy: const [],
            now: DateTime(2020, 1, 1),
          ),
        );
        date = date.addDays(1);
      }
      expect(grids.length, 7);
      for (final grid in grids) {
        expect(grid.length, 32);
      }
      final sunday = grids.last; // 2026-03-29
      final sundayNine = sunday.firstWhere((s) => s.startMinutes == 540);
      expect(sundayNine.state, SlotState.highlighted);
    }, skip: _isStockholm ? false : _needsStockholm);

    test('a busy interval spanning the DST hour (01:30-03:30) blocks nothing in the visible grid', () {
      final date = LocalDate(2026, 3, 29);
      final busy = [
        BusyInterval(
          start: DateTime(2026, 3, 29, 1, 30),
          end: DateTime(2026, 3, 29, 3, 30),
        ),
      ];
      final slots = buildSlotGrid(
        date: date,
        durationMinutes: 30,
        window: _emptyWindow,
        busy: busy,
        now: DateTime(2020, 1, 1),
      );
      for (final s in slots) {
        expect(s.state, isNot(SlotState.blocked));
      }
    }, skip: _isStockholm ? false : _needsStockholm);
  });
}
