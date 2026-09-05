import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';

EventType _sample({
  String id = 'abc123',
  String name = 'PT session',
  int durationMinutes = 60,
  String? location = 'Kungsholmen',
  String? notes,
  Set<int> preferredWeekdays = const {1, 3, 5},
  List<TimeWindow> preferredWindows = const [
    TimeWindow(startMinutes: 480, endMinutes: 1080),
  ],
  DateTime? createdAt,
}) {
  return EventType(
    id: id,
    name: name,
    durationMinutes: durationMinutes,
    location: location,
    notes: notes,
    preferredWeekdays: preferredWeekdays,
    preferredWindows: preferredWindows,
    createdAt: createdAt ?? DateTime(2026, 9, 4, 10, 0),
  );
}

void main() {
  group('EventType JSON shape', () {
    test('toJson matches the excerpt sample byte for byte', () {
      final eventType = _sample();

      const expected =
          '{"id":"abc123","name":"PT session","durationMinutes":60,'
          '"location":"Kungsholmen","notes":null,'
          '"preferredWeekdays":[1,3,5],'
          '"preferredWindows":[{"startMinutes":480,"endMinutes":1080}],'
          '"createdAt":"2026-09-04T10:00:00.000"}';

      expect(jsonEncode(eventType.toJson()), expected);
    });

    test('notes is null in JSON when absent', () {
      final eventType = _sample(notes: null);
      expect(eventType.toJson()['notes'], isNull);
    });

    test('preferredWeekdays serialises as a sorted array regardless of '
        'insertion order', () {
      final eventType = _sample(preferredWeekdays: {5, 1, 3});
      expect(eventType.toJson()['preferredWeekdays'], [1, 3, 5]);
    });

    test('fromJson reads the pre-multiple-windows shape', () {
      const source =
          '{"id":"...","name":"PT session","durationMinutes":60,'
          '"location":"Kungsholmen","notes":null,'
          '"preferredWeekdays":[1,3,5],"preferredStartMinutes":480,'
          '"preferredEndMinutes":1080,'
          '"createdAt":"2026-09-04T10:00:00.000"}';

      final eventType = EventType.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );

      expect(eventType.id, '...');
      expect(eventType.name, 'PT session');
      expect(eventType.durationMinutes, 60);
      expect(eventType.location, 'Kungsholmen');
      expect(eventType.notes, isNull);
      expect(eventType.preferredWeekdays, {1, 3, 5});
      expect(eventType.preferredStartMinutes, 480);
      expect(eventType.preferredEndMinutes, 1080);
      expect(eventType.createdAt, DateTime(2026, 9, 4, 10, 0));
      expect(eventType.preferredWindows, [
        const TimeWindow(startMinutes: 480, endMinutes: 1080),
      ]);
    });

    test('every window survives the round trip', () {
      final eventType = _sample(
        preferredWindows: const [
          TimeWindow(startMinutes: 420, endMinutes: 540),
          TimeWindow(startMinutes: 960, endMinutes: 1140),
        ],
      );
      final decoded = EventType.fromJson(
        jsonDecode(jsonEncode(eventType.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.preferredWindows, eventType.preferredWindows);
      expect(decoded, eventType);
    });
  });

  group('EventType round trip', () {
    test('jsonEncode/jsonDecode round trips to an equal instance', () {
      final eventType = _sample();
      final decoded = EventType.fromJson(
        jsonDecode(jsonEncode(eventType.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, eventType);
    });

    test('createdAt survives the round trip as a local, equal DateTime', () {
      final eventType = _sample(createdAt: DateTime(2026, 9, 4, 10, 30, 15));
      final json = eventType.toJson();
      final decoded = EventType.fromJson(json);

      expect(decoded.createdAt.isUtc, isFalse);
      expect(decoded.createdAt, eventType.createdAt);
    });

    test('fromJson throws FormatException, not a cast error, on a missing '
        'id', () {
      final json = _sample().toJson()..remove('id');

      expect(() => EventType.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson throws FormatException on a missing createdAt', () {
      final json = _sample().toJson()..remove('createdAt');

      expect(() => EventType.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson throws FormatException on a missing preferredWeekdays', () {
      final json = _sample().toJson()..remove('preferredWeekdays');

      expect(() => EventType.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('EventType equality and hashCode', () {
    test('two instances with the same field values are equal', () {
      final a = _sample();
      final b = _sample();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('equal regardless of preferredWeekdays insertion order', () {
      final a = _sample(preferredWeekdays: {1, 3, 5});
      final b = _sample(preferredWeekdays: {5, 3, 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differ when a field differs', () {
      final a = _sample();
      final b = _sample(name: 'Physio');
      expect(a, isNot(b));
    });
  });

  group('EventType copyWith', () {
    test('copies every field when given', () {
      final original = _sample();
      final createdAt = DateTime(2026, 1, 1, 8, 0);
      final copy = original.copyWith(
        id: 'new-id',
        name: 'Physio',
        durationMinutes: 45,
        location: 'Vasastan',
        notes: 'Bring insurance card',
        preferredWeekdays: {2, 4},
        preferredWindows: [TimeWindow(startMinutes: 540, endMinutes: 1020)],
        createdAt: createdAt,
      );

      expect(copy.id, 'new-id');
      expect(copy.name, 'Physio');
      expect(copy.durationMinutes, 45);
      expect(copy.location, 'Vasastan');
      expect(copy.notes, 'Bring insurance card');
      expect(copy.preferredWeekdays, {2, 4});
      expect(copy.preferredStartMinutes, 540);
      expect(copy.preferredEndMinutes, 1020);
      expect(copy.createdAt, createdAt);
    });

    test('keeps original values when nothing is given', () {
      final original = _sample();
      expect(original.copyWith(), original);
    });

    test('can explicitly set location and notes to null', () {
      final original = _sample(location: 'Kungsholmen', notes: 'Some notes');
      final copy = original.copyWith(location: null, notes: null);
      expect(copy.location, isNull);
      expect(copy.notes, isNull);
    });
  });

  group('EventType.validateName', () {
    test('empty name is required', () {
      expect(EventType.validateName(''), 'Name is required.');
    });

    test('blank name is required', () {
      expect(EventType.validateName('   '), 'Name is required.');
    });

    test('name over 40 characters is rejected', () {
      final tooLong = 'a' * 41;
      expect(EventType.validateName(tooLong), isNotNull);
    });

    test('valid name returns null', () {
      expect(EventType.validateName('PT session'), isNull);
    });
  });

  group('EventType.validateDuration', () {
    test('too short is rejected', () {
      expect(EventType.validateDuration(0), isNotNull);
    });

    test('too long is rejected', () {
      expect(EventType.validateDuration(485), isNotNull);
    });

    test('not a multiple of 5 is rejected', () {
      expect(EventType.validateDuration(47), isNotNull);
    });

    test('valid duration returns null', () {
      expect(EventType.validateDuration(60), isNull);
    });
  });

  group('EventType.validateWindow', () {
    test('end before start plus duration is rejected with the exact '
        'message', () {
      expect(
        EventType.validateWindow(start: 480, end: 520, duration: 60),
        'End must be after start plus the duration.',
      );
    });

    test('start outside 06:00-22:00 is rejected', () {
      expect(
        EventType.validateWindow(start: 300, end: 400, duration: 60),
        isNotNull,
      );
    });

    test('start not on a 30 minute mark is rejected', () {
      expect(
        EventType.validateWindow(start: 485, end: 600, duration: 60),
        isNotNull,
      );
    });

    test('end after 22:00 is rejected', () {
      expect(
        EventType.validateWindow(start: 1290, end: 1350, duration: 60),
        isNotNull,
      );
    });

    test('valid window returns null', () {
      expect(
        EventType.validateWindow(start: 480, end: 1080, duration: 60),
        isNull,
      );
    });
  });
}
