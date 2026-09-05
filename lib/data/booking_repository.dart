import 'dart:convert';

import 'local_store.dart';
import 'models/booking.dart';

/// Reads and writes the booking list. See `docs/architecture.md`, section
/// "Files, not a database".
abstract interface class BookingRepository {
  /// Every booking, sorted by [Booking.start] descending.
  Future<List<Booking>> getAll();

  /// Bookings for [eventTypeId], sorted by [Booking.start] descending.
  Future<List<Booking>> getForEventType(String eventTypeId);

  /// The booking for [eventTypeId] with the greatest [Booking.start],
  /// whether it is in the past or the future. `null` if there are none.
  Future<Booking?> latestForEventType(String eventTypeId);

  Future<void> add(Booking booking);

  /// Removes every booking for [eventTypeId]. Other cards' bookings are
  /// left alone.
  Future<void> deleteForEventType(String eventTypeId);

  /// Removes the bookings whose [Booking.id] is in [bookingIds]. Ids that
  /// are not stored are ignored.
  Future<void> deleteByIds(Set<String> bookingIds);
}

/// [BookingRepository] backed by a [LocalStore]. Holds no in-memory
/// cache; every call reads the store fresh.
class LocalBookingRepository implements BookingRepository {
  LocalBookingRepository(this._store);

  final LocalStore _store;

  static const _key = 'bookings';

  Future<List<Booking>> _readAll() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException(
        'Expected a JSON array in the "bookings" document.',
      );
    }
    return decoded
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<Booking> bookings) async {
    final encoded = jsonEncode(bookings.map((e) => e.toJson()).toList());
    await _store.write(_key, encoded);
  }

  @override
  Future<List<Booking>> getAll() async {
    final bookings = await _readAll();
    bookings.sort((a, b) => b.start.compareTo(a.start));
    return bookings;
  }

  @override
  Future<List<Booking>> getForEventType(String eventTypeId) async {
    final bookings = await _readAll();
    final forEventType = bookings
        .where((b) => b.eventTypeId == eventTypeId)
        .toList();
    forEventType.sort((a, b) => b.start.compareTo(a.start));
    return forEventType;
  }

  @override
  Future<Booking?> latestForEventType(String eventTypeId) async {
    final bookings = await _readAll();
    Booking? latest;
    for (final booking in bookings) {
      if (booking.eventTypeId != eventTypeId) continue;
      if (latest == null || booking.start.isAfter(latest.start)) {
        latest = booking;
      }
    }
    return latest;
  }

  @override
  Future<void> add(Booking booking) async {
    final bookings = await _readAll();
    bookings.add(booking);
    await _writeAll(bookings);
  }

  @override
  Future<void> deleteForEventType(String eventTypeId) async {
    final bookings = await _readAll();
    bookings.removeWhere((b) => b.eventTypeId == eventTypeId);
    await _writeAll(bookings);
  }

  @override
  Future<void> deleteByIds(Set<String> bookingIds) async {
    if (bookingIds.isEmpty) return;
    final bookings = await _readAll();
    final before = bookings.length;
    bookings.removeWhere((b) => bookingIds.contains(b.id));
    if (bookings.length == before) return;
    await _writeAll(bookings);
  }
}
