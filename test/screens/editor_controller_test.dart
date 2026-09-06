import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/editor/editor_controller.dart';
import 'package:recur/screens/editor/event_prefill.dart';

import '../helpers/fakes.dart';

void main() {
  group('load', () {
    test('loading an existing card sets savedName', () async {
      final testDeps = buildTestDeps();
      final original = EventType(
        id: 'et-1',
        name: 'PT session',
        durationMinutes: 60,
        preferredWeekdays: const {1, 2, 3, 4, 5},
        preferredWindows: [TimeWindow(startMinutes: 480, endMinutes: 1080)],
        createdAt: DateTime(2020, 1, 1),
      );
      await testDeps.deps.eventTypes.upsert(original);

      final controller = EditorController(
        deps: testDeps.deps,
        eventTypeId: 'et-1',
      );
      await controller.load();

      expect(controller.savedName, 'PT session');
      controller.setName('');
      expect(controller.savedName, 'PT session');
    });

    test('a missing id sets notFound', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(
        deps: testDeps.deps,
        eventTypeId: 'missing',
      );

      await controller.load();

      expect(controller.notFound, isTrue);
      expect(controller.loadError, isFalse);
      expect(controller.loading, isFalse);
    });

    test('a repository read failure sets loadError', () async {
      final testDeps = buildTestDeps();
      await testDeps.store.write('event_types', 'not json');
      final controller = EditorController(
        deps: testDeps.deps,
        eventTypeId: 'et-1',
      );

      await controller.load();

      expect(controller.loadError, isTrue);
      expect(controller.notFound, isFalse);
      expect(controller.loading, isFalse);
    });

    test('a new card sets neither notFound nor loadError', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);

      await controller.load();

      expect(controller.notFound, isFalse);
      expect(controller.loadError, isFalse);
      expect(controller.savedName, isNull);
    });
  });

  group('validation', () {
    test('a new controller starts with the D18 defaults', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      expect(controller.isNew, isTrue);
      expect(controller.durationMinutes, 60);
      expect(controller.weekdays, {1, 2, 3, 4, 5});
      expect(controller.windows, [
        const TimeWindow(startMinutes: 480, endMinutes: 1080),
      ]);
      expect(controller.isValid, isFalse);
    });

    test('nameError is null until the name is touched', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      expect(controller.nameError, isNull);
      controller.setName('');
      expect(controller.nameError, 'Name is required.');
      controller.setName('PT session');
      expect(controller.nameError, isNull);
    });

    test('durationError only applies to the custom field', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      expect(controller.durationError, isNull);
      controller.selectCustomDuration();
      controller.setCustomDurationText('7');
      expect(controller.durationError, 'Use 5 to 480 minutes in steps of 5.');
      controller.setCustomDurationText('75');
      expect(controller.durationError, isNull);
      controller.setCustomDurationText('');
      expect(controller.durationError, 'Use 5 to 480 minutes in steps of 5.');
    });

    test('windowError matches EventType.validateWindow', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      controller.setWindowStart(0, 1080);
      controller.setWindowEnd(0, 1100);
      expect(
        controller.windowError,
        'End must be after start plus the duration.',
      );
    });

    test(
      'isValid requires a name, at least one weekday, and no errors',
      () async {
        final testDeps = buildTestDeps();
        final controller = EditorController(deps: testDeps.deps);
        await controller.load();

        controller.setName('PT session');
        expect(controller.isValid, isTrue);

        for (final weekday in List.of(controller.weekdays)) {
          controller.toggleWeekday(weekday);
        }
        expect(controller.weekdays, isEmpty);
        expect(controller.isValid, isFalse);
      },
    );
  });

  group('preferred times', () {
    test('addWindow appends a window after the last one', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      controller.addWindow();

      expect(controller.windows, [
        const TimeWindow(startMinutes: 480, endMinutes: 1080),
        const TimeWindow(startMinutes: 1080, endMinutes: 1140),
      ]);
      expect(controller.windowError, isNull);
    });

    test('an added window is pulled back to fit before 22:00', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();
      controller.setWindowEnd(0, 1320);

      controller.addWindow();

      expect(
        controller.windows.last,
        const TimeWindow(startMinutes: 1260, endMinutes: 1320),
      );
      expect(controller.windowError, isNull);
    });

    test('setWindowStart and setWindowEnd change one window only', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();
      controller.addWindow();

      controller.setWindowStart(0, 420);
      controller.setWindowEnd(0, 600);

      expect(
        controller.windows.first,
        const TimeWindow(startMinutes: 420, endMinutes: 600),
      );
      expect(
        controller.windows.last,
        const TimeWindow(startMinutes: 1080, endMinutes: 1140),
      );
    });

    test('removeWindow drops it, but never the last one', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();
      controller.addWindow();

      controller.removeWindow(0);
      expect(controller.windows, [
        const TimeWindow(startMinutes: 1080, endMinutes: 1140),
      ]);

      controller.removeWindow(0);
      expect(controller.windows, hasLength(1));
    });

    test('windowError reports the first broken window', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();
      controller.addWindow();
      controller.setWindowEnd(1, 1085);

      expect(
        controller.windowError,
        'End must be after start plus the duration.',
      );
      expect(controller.isValid, isFalse);
    });

    test('every window is saved', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();
      controller.setName('PT session');
      controller.setWindowStart(0, 420);
      controller.setWindowEnd(0, 600);
      controller.addWindow();

      await controller.save();

      final saved = (await testDeps.deps.eventTypes.getAll()).single;
      expect(saved.preferredWindows, [
        const TimeWindow(startMinutes: 420, endMinutes: 600),
        const TimeWindow(startMinutes: 600, endMinutes: 660),
      ]);
    });
  });

  group('applyPrefill', () {
    test('fills the whole draft in from a calendar event', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      controller.applyPrefill(
        EventPrefill(
          name: 'Physio',
          durationMinutes: 45,
          location: 'Vasastan',
          notes: 'Bring the referral',
          weekdays: const {2, 4},
          windows: const [TimeWindow(startMinutes: 600, endMinutes: 720)],
          sourceStart: DateTime(2026, 9, 8, 10),
          occurrences: 3,
        ),
      );

      expect(controller.name, 'Physio');
      expect(controller.durationMinutes, 45);
      expect(controller.isCustomDuration, isFalse);
      expect(controller.location, 'Vasastan');
      expect(controller.notes, 'Bring the referral');
      expect(controller.weekdays, {2, 4});
      expect(controller.windows, [
        const TimeWindow(startMinutes: 600, endMinutes: 720),
      ]);
      expect(controller.isValid, isTrue);
    });

    test('a duration off the presets switches to Custom', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      controller.applyPrefill(
        EventPrefill(
          name: 'Physio',
          durationMinutes: 50,
          weekdays: const {2},
          windows: const [TimeWindow(startMinutes: 600, endMinutes: 720)],
          sourceStart: DateTime(2026, 9, 8, 10),
          occurrences: 1,
        ),
      );

      expect(controller.isCustomDuration, isTrue);
      expect(controller.customDurationText, '50');
      expect(controller.durationError, isNull);
    });
  });

  group('save', () {
    test('creates a new card with the D18 defaults', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();
      controller.setName('PT session');

      await controller.save();

      final all = await testDeps.deps.eventTypes.getAll();
      expect(all, hasLength(1));
      expect(all.first.name, 'PT session');
      expect(all.first.id, 'id-1');
      expect(all.first.durationMinutes, 60);
      expect(all.first.preferredWeekdays, {1, 2, 3, 4, 5});
      expect(all.first.preferredStartMinutes, 480);
      expect(all.first.preferredEndMinutes, 1080);
      expect(all.first.createdAt, testDeps.clock.now());
    });

    test('editing an existing card keeps its id and createdAt', () async {
      final testDeps = buildTestDeps();
      final original = EventType(
        id: 'et-1',
        name: 'PT session',
        durationMinutes: 60,
        preferredWeekdays: const {1, 2, 3, 4, 5},
        preferredWindows: [TimeWindow(startMinutes: 480, endMinutes: 1080)],
        createdAt: DateTime(2020, 1, 1),
      );
      await testDeps.deps.eventTypes.upsert(original);

      final controller = EditorController(
        deps: testDeps.deps,
        eventTypeId: 'et-1',
      );
      await controller.load();
      controller.setName('PT session (updated)');

      await controller.save();

      final saved = await testDeps.deps.eventTypes.getById('et-1');
      expect(saved!.id, 'et-1');
      expect(saved.createdAt, DateTime(2020, 1, 1));
      expect(saved.name, 'PT session (updated)');
    });

    test('blank location and notes are saved as null', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();
      controller.setName('PT session');
      controller.setLocation('   ');
      controller.setNotes('  ');

      await controller.save();

      final saved = (await testDeps.deps.eventTypes.getAll()).single;
      expect(saved.location, isNull);
      expect(saved.notes, isNull);
    });
  });

  group('delete', () {
    test(
      'removes the card and its bookings, never touches the calendar',
      () async {
        final testDeps = buildTestDeps();
        final original = EventType(
          id: 'et-1',
          name: 'PT session',
          durationMinutes: 60,
          preferredWeekdays: const {1, 2, 3, 4, 5},
          preferredWindows: [TimeWindow(startMinutes: 480, endMinutes: 1080)],
          createdAt: DateTime(2020, 1, 1),
        );
        await testDeps.deps.eventTypes.upsert(original);

        final controller = EditorController(
          deps: testDeps.deps,
          eventTypeId: 'et-1',
        );
        await controller.load();

        await controller.delete();

        expect(await testDeps.deps.eventTypes.getById('et-1'), isNull);
        expect(await testDeps.deps.bookings.getForEventType('et-1'), isEmpty);
        expect(testDeps.calendar.created, isEmpty);
      },
    );
  });
}
