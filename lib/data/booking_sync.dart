/// Keeps Recur's booking log honest about what is still in the phone
/// calendar.
///
/// Recur writes an event and notes the booking, but the calendar is the
/// user's, and they can delete the event there. Nothing tells the app when
/// that happens, so the log is checked against the calendar on a load and
/// bookings whose event is gone are dropped. See `docs/architecture.md`,
/// section "Bookings that vanish from the calendar".
library;

import '../calendar/calendar_gateway.dart';
import 'booking_repository.dart';
import 'models/booking.dart';

/// How many of each card's most recent bookings are checked. The
/// last-booked line reads one and the suggestion window reads three, so
/// older records change nothing on screen and are left alone rather than
/// costing a calendar lookup each on every load.
const int recentBookingsChecked = 5;

/// Removes the bookings whose calendar event no longer exists, and returns
/// their ids.
///
/// Does nothing at all — and never throws — when the calendar cannot be
/// read: no access, or a failing lookup. A calendar the app cannot see is
/// not the same as an event the user deleted, and guessing wrong would
/// throw away history that cannot be got back.
Future<Set<String>> pruneVanishedBookings({
  required BookingRepository bookings,
  required CalendarGateway calendar,
}) async {
  try {
    if (await calendar.checkAccess() != CalendarAccess.granted) return {};

    final all = await bookings.getAll();
    if (all.isEmpty) return {};

    final recent = _mostRecentPerEventType(all);
    final alive = await calendar.existingEventIds({
      for (final booking in recent) booking.calendarEventId,
    });

    final gone = {
      for (final booking in recent)
        if (!alive.contains(booking.calendarEventId)) booking.id,
    };
    if (gone.isEmpty) return {};

    await bookings.deleteByIds(gone);
    return gone;
  } catch (_) {
    return {};
  }
}

/// The [recentBookingsChecked] newest bookings of every card in [all].
List<Booking> _mostRecentPerEventType(List<Booking> all) {
  final byEventType = <String, List<Booking>>{};
  for (final booking in all) {
    byEventType.putIfAbsent(booking.eventTypeId, () => []).add(booking);
  }

  final recent = <Booking>[];
  for (final forEventType in byEventType.values) {
    forEventType.sort((a, b) => b.start.compareTo(a.start));
    recent.addAll(forEventType.take(recentBookingsChecked));
  }
  return recent;
}
