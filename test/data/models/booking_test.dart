import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/models/booking.dart';

Booking _sample({
  String id = 'bk1',
  String eventTypeId = 'et1',
  DateTime? start,
  DateTime? end,
  String calendarId = '1',
  String calendarEventId = '42',
  DateTime? createdAt,
}) {
  return Booking(
    id: id,
    eventTypeId: eventTypeId,
    start: start ?? DateTime(2026, 9, 8, 10, 0),
    end: end ?? DateTime(2026, 9, 8, 11, 0),
    calendarId: calendarId,
    calendarEventId: calendarEventId,
    createdAt: createdAt ?? DateTime(2026, 9, 4, 10, 0),
  );
}

void main() {
  group('Booking JSON shape', () {
    test('toJson matches the excerpt sample byte for byte', () {
      final booking = _sample(id: 'abc123', eventTypeId: 'def456');

      const expected =
          '{"id":"abc123","eventTypeId":"def456",'
          '"start":"2026-09-08T10:00:00.000",'
          '"end":"2026-09-08T11:00:00.000",'
          '"calendarId":"1","calendarEventId":"42",'
          '"createdAt":"2026-09-04T10:00:00.000"}';

      expect(jsonEncode(booking.toJson()), expected);
    });

    test('fromJson parses the literal excerpt sample', () {
      const source =
          '{"id":"...","eventTypeId":"...",'
          '"start":"2026-09-08T10:00:00.000",'
          '"end":"2026-09-08T11:00:00.000",'
          '"calendarId":"1","calendarEventId":"42",'
          '"createdAt":"2026-09-04T10:00:00.000"}';

      final booking = Booking.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );

      expect(booking.id, '...');
      expect(booking.eventTypeId, '...');
      expect(booking.start, DateTime(2026, 9, 8, 10, 0));
      expect(booking.end, DateTime(2026, 9, 8, 11, 0));
      expect(booking.calendarId, '1');
      expect(booking.calendarEventId, '42');
      expect(booking.createdAt, DateTime(2026, 9, 4, 10, 0));
    });
  });

  group('Booking round trip', () {
    test('jsonEncode/jsonDecode round trips to an equal instance', () {
      final booking = _sample();
      final decoded = Booking.fromJson(
        jsonDecode(jsonEncode(booking.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, booking);
    });

    test('start and end survive the round trip as local, equal DateTimes', () {
      final booking = _sample(
        start: DateTime(2026, 9, 8, 10, 0),
        end: DateTime(2026, 9, 8, 11, 0),
      );
      final decoded = Booking.fromJson(booking.toJson());

      expect(decoded.start.isUtc, isFalse);
      expect(decoded.start, booking.start);
      expect(decoded.end.isUtc, isFalse);
      expect(decoded.end, booking.end);
    });

    test('fromJson throws FormatException, not a cast error, on a missing '
        'id', () {
      final json = _sample().toJson()..remove('id');

      expect(() => Booking.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson throws FormatException on a missing calendarEventId', () {
      final json = _sample().toJson()..remove('calendarEventId');

      expect(() => Booking.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('Booking equality and hashCode', () {
    test('two instances with the same field values are equal', () {
      final a = _sample();
      final b = _sample();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differ when a field differs', () {
      final a = _sample();
      final b = _sample(calendarEventId: '99');
      expect(a, isNot(b));
    });
  });
}
