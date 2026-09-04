/// A calendar date with no time or zone.
///
/// Comparable and hashable, so it can be used as a map key or sorted.
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  /// Builds a [LocalDate] from the date portion of [dt].
  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate(dt.year, dt.month, dt.day);

  final int year;
  final int month;
  final int day;

  /// 1 = Monday ... 7 = Sunday, same as [DateTime.monday]..[DateTime.sunday].
  int get weekday => DateTime(year, month, day).weekday;

  /// The date [n] days after this one. [n] may be negative.
  LocalDate addDays(int n) {
    final dt = DateTime(year, month, day + n);
    return LocalDate.fromDateTime(dt);
  }

  /// The Monday of the week this date falls in.
  LocalDate get mondayOfWeek => addDays(-(weekday - 1));

  /// Local wall-clock [DateTime] at [minutesOfDay] on this date.
  DateTime at(int minutesOfDay) =>
      DateTime(year, month, day, minutesOfDay ~/ 60, minutesOfDay % 60);

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
