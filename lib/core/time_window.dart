/// A span of time-of-day, in minutes since midnight.
///
/// A card can prefer more than one window in a day ("mornings, or late
/// afternoon"), so the preference is a list of these rather than one pair
/// of times. See `docs/architecture.md`, section "The data".
library;

import 'time_of_day_minutes.dart';

/// A half-open span `[startMinutes, endMinutes)` within one day.
final class TimeWindow implements Comparable<TimeWindow> {
  const TimeWindow({required this.startMinutes, required this.endMinutes});

  /// Minutes since midnight, 360..1320.
  final int startMinutes;

  /// Minutes since midnight, greater than [startMinutes], up to 1320.
  final int endMinutes;

  /// Whether an appointment running `[start, end)` fits inside this window.
  bool contains({required int start, required int end}) =>
      start >= startMinutes && end <= endMinutes;

  TimeWindow copyWith({int? startMinutes, int? endMinutes}) => TimeWindow(
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
  );

  Map<String, dynamic> toJson() => {
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
  };

  factory TimeWindow.fromJson(Map<String, dynamic> json) {
    final start = json['startMinutes'];
    final end = json['endMinutes'];
    if (start is! int || end is! int) {
      throw const FormatException(
        'A TimeWindow needs integer "startMinutes" and "endMinutes".',
      );
    }
    return TimeWindow(startMinutes: start, endMinutes: end);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeWindow &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);

  /// Orders by [startMinutes], then [endMinutes].
  @override
  int compareTo(TimeWindow other) {
    if (startMinutes != other.startMinutes) {
      return startMinutes.compareTo(other.startMinutes);
    }
    return endMinutes.compareTo(other.endMinutes);
  }

  @override
  String toString() =>
      'TimeWindow(${formatMinutes(startMinutes)}-${formatMinutes(endMinutes)})';
}

/// Whether any window in [windows] contains `[start, end)`.
bool windowsContain(
  List<TimeWindow> windows, {
  required int start,
  required int end,
}) {
  for (final window in windows) {
    if (window.contains(start: start, end: end)) return true;
  }
  return false;
}

/// Element-wise equality for two lists of windows, order included.
bool timeWindowListEquals(List<TimeWindow> a, List<TimeWindow> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
