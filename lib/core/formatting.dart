/// Fixed English, hand-written formatting. No `intl`, no `DateFormat`.
library;

import 'local_date.dart';
import 'time_of_day_minutes.dart';

/// Weekday abbreviations, Monday first. Index with `weekday - 1` for a
/// `DateTime`-style weekday (1 = Monday .. 7 = Sunday).
const List<String> weekdayAbbrev = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthAbbrev = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a duration in minutes, e.g. `formatDuration(45) == '45 min'`.
String formatDuration(int minutes) => '$minutes min';

/// Formats [minutesOfDay] as `HH:mm`, e.g. `formatTime(600) == '10:00'`.
String formatTime(int minutesOfDay) => formatMinutes(minutesOfDay);

/// Formats [date] as `Tue 8 Sep`.
String formatDayShort(LocalDate date) {
  final weekday = weekdayAbbrev[date.weekday - 1];
  final month = _monthAbbrev[date.month - 1];
  return '$weekday ${date.day} $month';
}

/// Formats [monday], the Monday of a week, as `Week of 7 Sep`.
String formatWeekOf(LocalDate monday) {
  final month = _monthAbbrev[monday.month - 1];
  return 'Week of ${monday.day} $month';
}

/// Formats a span of time on [date] as `Tue 8 Sep, 10:00 to 11:00`.
String formatDaySpan({
  required LocalDate date,
  required int startMinutes,
  required int endMinutes,
}) {
  return '${formatDayShort(date)}, '
      '${formatMinutes(startMinutes)} to ${formatMinutes(endMinutes)}';
}

/// Formats when a card was last booked, relative to [now].
///
/// [latestStart] is the start of the most recent booking, or `null` if the
/// card has never been booked. Day differences are computed on calendar
/// dates, not 24-hour spans: a booking at 23:00 yesterday reads
/// `Last booked yesterday` at 01:00 today.
String formatLastBooked({
  required DateTime? latestStart,
  required DateTime now,
}) {
  if (latestStart == null) return 'Not booked yet';

  if (latestStart.isAfter(now)) {
    return 'Booked for ${formatDayShort(LocalDate.fromDateTime(latestStart))}';
  }

  final startDate = LocalDate.fromDateTime(latestStart);
  final nowDate = LocalDate.fromDateTime(now);
  final days = _daysBetween(startDate, nowDate);

  if (days <= 0) return 'Last booked today';
  if (days == 1) return 'Last booked yesterday';
  if (days < 7) return 'Last booked $days days ago';
  if (days < 28) {
    final weeks = days ~/ 7;
    return 'Last booked ${_pluralized(weeks, 'week')} ago';
  }
  final months = ((days - 28) ~/ 30) + 1;
  return 'Last booked ${_pluralized(months, 'month')} ago';
}

/// The number of calendar days between [from] and [to], computed without
/// regard to daylight saving time.
int _daysBetween(LocalDate from, LocalDate to) {
  final fromUtc = DateTime.utc(from.year, from.month, from.day);
  final toUtc = DateTime.utc(to.year, to.month, to.day);
  return toUtc.difference(fromUtc).inDays;
}

String _pluralized(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
