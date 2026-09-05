import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/event_type_repository.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/data/models/event_type.dart';

EventType _sample({
  String id = 'abc123',
  String name = 'PT session',
  int durationMinutes = 60,
  String? location = 'Kungsholmen',
  String? notes,
  Set<int> preferredWeekdays = const {1, 3, 5},
  int preferredStartMinutes = 480,
  int preferredEndMinutes = 1080,
  DateTime? createdAt,
}) {
  return EventType(
    id: id,
    name: name,
    durationMinutes: durationMinutes,
    location: location,
    notes: notes,
    preferredWeekdays: preferredWeekdays,
    preferredWindows: [
      TimeWindow(
        startMinutes: preferredStartMinutes,
        endMinutes: preferredEndMinutes,
      ),
    ],
    createdAt: createdAt ?? DateTime(2026, 9, 4, 10, 0),
  );
}

void main() {
  group('LocalEventTypeRepository', () {
    late InMemoryLocalStore store;
    late LocalEventTypeRepository repository;

    setUp(() {
      store = InMemoryLocalStore();
      repository = LocalEventTypeRepository(store);
    });

    test('getAll returns an empty list when the store is empty', () async {
      expect(await repository.getAll(), isEmpty);
    });

    test('getById returns null when the store is empty', () async {
      expect(await repository.getById('abc123'), isNull);
    });

    test('upsert then getById returns the card', () async {
      final eventType = _sample();
      await repository.upsert(eventType);

      expect(await repository.getById('abc123'), eventType);
    });

    test('upsert then getAll returns the card', () async {
      final eventType = _sample();
      await repository.upsert(eventType);

      expect(await repository.getAll(), [eventType]);
    });

    test('upsert replaces the existing card with the same id', () async {
      await repository.upsert(_sample(name: 'PT session'));
      final updated = _sample(name: 'Massage');
      await repository.upsert(updated);

      final all = await repository.getAll();
      expect(all, [updated]);
    });

    test('delete removes the card', () async {
      final eventType = _sample();
      await repository.upsert(eventType);
      await repository.delete(eventType.id);

      expect(await repository.getAll(), isEmpty);
      expect(await repository.getById(eventType.id), isNull);
    });

    test('delete is a no-op when the card is missing', () async {
      final eventType = _sample();
      await repository.upsert(eventType);
      await repository.delete('does-not-exist');

      expect(await repository.getAll(), [eventType]);
    });

    test('getAll sorts by createdAt ascending, then by id', () async {
      final older = _sample(
        id: 'b',
        name: 'Older',
        createdAt: DateTime(2026, 1, 1),
      );
      final newer = _sample(
        id: 'a',
        name: 'Newer',
        createdAt: DateTime(2026, 6, 1),
      );
      final sameTimeA = _sample(
        id: 'x',
        name: 'Same time, id x',
        createdAt: DateTime(2026, 3, 1),
      );
      final sameTimeB = _sample(
        id: 'y',
        name: 'Same time, id y',
        createdAt: DateTime(2026, 3, 1),
      );

      // Insert out of order.
      await repository.upsert(newer);
      await repository.upsert(sameTimeB);
      await repository.upsert(older);
      await repository.upsert(sameTimeA);

      final all = await repository.getAll();
      expect(all.map((e) => e.id).toList(), ['b', 'x', 'y', 'a']);
    });

    test(
      'data survives a second repository instance on the same store',
      () async {
        final eventType = _sample();
        await repository.upsert(eventType);

        final second = LocalEventTypeRepository(store);
        expect(await second.getAll(), [eventType]);
      },
    );

    test('a malformed document throws FormatException', () async {
      await store.write('event_types', 'not json');

      expect(() => repository.getAll(), throwsA(isA<FormatException>()));
    });

    test(
      'a document that is not a JSON array throws FormatException',
      () async {
        await store.write('event_types', '{"not":"a list"}');

        expect(() => repository.getAll(), throwsA(isA<FormatException>()));
      },
    );
  });
}
