import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/booking_repository.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/data/models/booking.dart';

Booking _sample({
  String id = 'b1',
  String eventTypeId = 'et1',
  DateTime? start,
  DateTime? end,
  String calendarId = 'cal1',
  String calendarEventId = 'evt1',
  DateTime? createdAt,
}) {
  final resolvedStart = start ?? DateTime(2026, 9, 4, 10, 0);
  return Booking(
    id: id,
    eventTypeId: eventTypeId,
    start: resolvedStart,
    end: end ?? resolvedStart.add(const Duration(minutes: 60)),
    calendarId: calendarId,
    calendarEventId: calendarEventId,
    createdAt: createdAt ?? DateTime(2026, 9, 1, 9, 0),
  );
}

void main() {
  group('LocalBookingRepository', () {
    late InMemoryLocalStore store;
    late LocalBookingRepository repository;

    setUp(() {
      store = InMemoryLocalStore();
      repository = LocalBookingRepository(store);
    });

    test(
      'getForEventType returns an empty list when the store is empty',
      () async {
        expect(await repository.getForEventType('et1'), isEmpty);
      },
    );

    test('latestForEventType returns null when the store is empty', () async {
      expect(await repository.latestForEventType('et1'), isNull);
    });

    test('add then getForEventType returns the booking', () async {
      final booking = _sample();
      await repository.add(booking);

      expect(await repository.getForEventType('et1'), [booking]);
    });

    test('getForEventType sorts by start descending', () async {
      final earliest = _sample(id: 'b1', start: DateTime(2026, 1, 1, 10, 0));
      final latest = _sample(id: 'b2', start: DateTime(2026, 6, 1, 10, 0));
      final middle = _sample(id: 'b3', start: DateTime(2026, 3, 1, 10, 0));

      await repository.add(earliest);
      await repository.add(latest);
      await repository.add(middle);

      final all = await repository.getForEventType('et1');
      expect(all.map((b) => b.id).toList(), ['b2', 'b3', 'b1']);
    });

    test('getForEventType only returns bookings for that event type', () async {
      final forEt1 = _sample(id: 'b1', eventTypeId: 'et1');
      final forEt2 = _sample(id: 'b2', eventTypeId: 'et2');

      await repository.add(forEt1);
      await repository.add(forEt2);

      expect(await repository.getForEventType('et1'), [forEt1]);
    });

    test('latestForEventType returns the booking with the greatest start, '
        'including a future one', () async {
      final now = DateTime.now();
      final past = _sample(
        id: 'past',
        start: now.subtract(const Duration(days: 30)),
      );
      final future = _sample(
        id: 'future',
        start: now.add(const Duration(days: 30)),
      );
      final middle = _sample(id: 'middle', start: now);

      await repository.add(past);
      await repository.add(future);
      await repository.add(middle);

      final latest = await repository.latestForEventType('et1');
      expect(latest?.id, 'future');
    });

    test('deleteForEventType leaves other cards\' bookings alone', () async {
      final forEt1 = _sample(id: 'b1', eventTypeId: 'et1');
      final forEt2 = _sample(id: 'b2', eventTypeId: 'et2');

      await repository.add(forEt1);
      await repository.add(forEt2);
      await repository.deleteForEventType('et1');

      expect(await repository.getForEventType('et1'), isEmpty);
      expect(await repository.getForEventType('et2'), [forEt2]);
    });

    test(
      'data survives a second repository instance on the same store',
      () async {
        final booking = _sample();
        await repository.add(booking);

        final second = LocalBookingRepository(store);
        expect(await second.getForEventType('et1'), [booking]);
      },
    );

    test('a malformed document throws FormatException', () async {
      await store.write('bookings', 'not json');

      expect(
        () => repository.getForEventType('et1'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'a document that is not a JSON array throws FormatException',
      () async {
        await store.write('bookings', '{"not":"a list"}');

        expect(
          () => repository.getForEventType('et1'),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
