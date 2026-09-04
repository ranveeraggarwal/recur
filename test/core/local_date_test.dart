import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/local_date.dart';

void main() {
  group('LocalDate.fromDateTime', () {
    test('takes only the date portion', () {
      final date = LocalDate.fromDateTime(DateTime(2026, 9, 8, 14, 30));
      expect(date, const LocalDate(2026, 9, 8));
    });
  });

  group('addDays', () {
    test('crosses a month end', () {
      const date = LocalDate(2026, 1, 30);
      expect(date.addDays(3), const LocalDate(2026, 2, 2));
    });

    test('crosses a year end', () {
      const date = LocalDate(2026, 12, 30);
      expect(date.addDays(3), const LocalDate(2027, 1, 2));
    });

    test('accepts negative offsets', () {
      const date = LocalDate(2026, 3, 1);
      expect(date.addDays(-1), const LocalDate(2026, 2, 28));
    });
  });

  group('mondayOfWeek', () {
    test('a Monday returns itself', () {
      // 2026-09-07 is a Monday.
      const monday = LocalDate(2026, 9, 7);
      expect(monday.mondayOfWeek, monday);
    });

    test('a Sunday returns the Monday six days earlier', () {
      // 2026-09-13 is a Sunday.
      const sunday = LocalDate(2026, 9, 13);
      expect(sunday.mondayOfWeek, const LocalDate(2026, 9, 7));
    });

    test('a Wednesday returns the Monday of that week', () {
      // 2026-09-09 is a Wednesday.
      const wednesday = LocalDate(2026, 9, 9);
      expect(wednesday.mondayOfWeek, const LocalDate(2026, 9, 7));
    });
  });

  group('weekday', () {
    test('matches DateTime.monday..sunday numbering', () {
      expect(const LocalDate(2026, 9, 7).weekday, DateTime.monday);
      expect(const LocalDate(2026, 9, 13).weekday, DateTime.sunday);
    });
  });

  group('at', () {
    test('builds a local wall-clock DateTime without adding a Duration '
        'across the Stockholm spring DST day', () {
      // 2026-03-29 is the Stockholm spring-forward day (02:00 -> 03:00).
      // This test passes in any zone: it checks that .at() constructs
      // the DateTime directly rather than by adding a Duration from
      // midnight.
      const date = LocalDate(2026, 3, 29);
      expect(date.at(360), DateTime(2026, 3, 29, 6, 0));
      expect(date.at(1290), DateTime(2026, 3, 29, 21, 30));
    });
  });

  group('equality, hashing, ordering, and printing', () {
    test('equal dates are == and share a hashCode', () {
      const a = LocalDate(2026, 9, 8);
      const b = LocalDate(2026, 9, 8);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('compareTo orders by year, then month, then day', () {
      const earlier = LocalDate(2026, 9, 8);
      const later = LocalDate(2026, 9, 9);
      expect(earlier.compareTo(later), lessThan(0));
      expect(later.compareTo(earlier), greaterThan(0));
      expect(earlier.compareTo(earlier), 0);
    });

    test('toString formats as yyyy-mm-dd', () {
      expect(const LocalDate(2026, 9, 8).toString(), '2026-09-08');
    });
  });
}
