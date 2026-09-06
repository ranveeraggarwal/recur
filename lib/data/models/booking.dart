/// A record that a card was booked into the phone calendar.
///
/// Bookings are never edited; they disappear only when their card is
/// deleted. See `docs/architecture.md`, section "The data".
library;

import 'json_helpers.dart';

final class Booking {
  const Booking({
    required this.id,
    required this.eventTypeId,
    required this.start,
    required this.end,
    required this.calendarId,
    required this.calendarEventId,
    required this.createdAt,
  });

  final String id;
  final String eventTypeId;

  /// The local wall-clock time the appointment starts.
  final DateTime start;

  /// [start] plus the card's duration.
  final DateTime end;

  /// The id of the phone calendar the event was written to.
  final String calendarId;

  /// The id the calendar gateway returned for the created event.
  final String calendarEventId;

  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventTypeId': eventTypeId,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'calendarId': calendarId,
      'calendarEventId': calendarEventId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: requireJson<String>(json, 'id', 'Booking'),
      eventTypeId: requireJson<String>(json, 'eventTypeId', 'Booking'),
      start: DateTime.parse(requireJson<String>(json, 'start', 'Booking')),
      end: DateTime.parse(requireJson<String>(json, 'end', 'Booking')),
      calendarId: requireJson<String>(json, 'calendarId', 'Booking'),
      calendarEventId: requireJson<String>(json, 'calendarEventId', 'Booking'),
      createdAt: DateTime.parse(
        requireJson<String>(json, 'createdAt', 'Booking'),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Booking &&
      other.id == id &&
      other.eventTypeId == eventTypeId &&
      other.start == start &&
      other.end == end &&
      other.calendarId == calendarId &&
      other.calendarEventId == calendarEventId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    eventTypeId,
    start,
    end,
    calendarId,
    calendarEventId,
    createdAt,
  );

  @override
  String toString() =>
      'Booking(id: $id, eventTypeId: $eventTypeId, start: $start, end: $end)';
}
