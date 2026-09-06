/// Minutes since midnight: 0..1440. 06:00 = 360, 22:00 = 1320.
library;

/// The earliest slot start, in minutes since midnight. 06:00.
const int dayStartMinutes = 6 * 60;

/// The latest slot end, in minutes since midnight. 22:00.
const int dayEndMinutes = 22 * 60;

/// The length of one slot, in minutes.
const int slotMinutes = 30;

/// The number of slots between [dayStartMinutes] and [dayEndMinutes].
const int slotsPerDay = 32;

/// Formats [minutesOfDay] as `HH:mm`, e.g. `06:00`, `21:30`.
String formatMinutes(int minutesOfDay) {
  final hours = minutesOfDay ~/ 60;
  final minutes = minutesOfDay % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

/// The number of minutes since midnight for the time-of-day portion of [dt].
int minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute;

/// Rounds [minutes] down to the slot mark at or below it, e.g.
/// `roundDownToSlot(605) == 600`.
int roundDownToSlot(int minutes) => minutes - (minutes % slotMinutes);

/// Rounds [minutes] up to the slot mark at or above it, e.g.
/// `roundUpToSlot(605) == 630`. A value already on a mark is unchanged.
int roundUpToSlot(int minutes) {
  final remainder = minutes % slotMinutes;
  return remainder == 0 ? minutes : minutes + (slotMinutes - remainder);
}
