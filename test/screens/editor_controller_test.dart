import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/editor/editor_controller.dart';

import '../helpers/fakes.dart';

void main() {
  group('validation', () {
    test('a new controller starts with the D18 defaults', () async {
      final testDeps = buildTestDeps();
      final controller = EditorController(deps: testDeps.deps);
      await controller.load();

      expect(controller.isNew, isTrue);
      expect(controller.durationMinutes, 60);
      expect(controller.weekdays, {1, 2, 3, 4, 5});
      expect(controller.startMinutes, 480);
      expect(controller.endMinutes, 1080);
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

      controller.setStartMinutes(1080);
      controller.setEndMinutes(1100);
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
        preferredStartMinutes: 480,
        preferredEndMinutes: 1080,
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
          preferredStartMinutes: 480,
          preferredEndMinutes: 1080,
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
