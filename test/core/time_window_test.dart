import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/time_window.dart';

void main() {
  group('TimeWindow', () {
    test('contains is inclusive of both edges', () {
      const window = TimeWindow(startMinutes: 480, endMinutes: 600);

      expect(window.contains(start: 480, end: 600), isTrue);
      expect(window.contains(start: 510, end: 570), isTrue);
      expect(window.contains(start: 450, end: 600), isFalse);
      expect(window.contains(start: 480, end: 630), isFalse);
    });

    test('copyWith replaces only what it is given', () {
      const window = TimeWindow(startMinutes: 480, endMinutes: 600);

      expect(
        window.copyWith(startMinutes: 540),
        const TimeWindow(startMinutes: 540, endMinutes: 600),
      );
      expect(
        window.copyWith(endMinutes: 660),
        const TimeWindow(startMinutes: 480, endMinutes: 660),
      );
      expect(window.copyWith(), window);
    });

    test('round trips through JSON', () {
      const window = TimeWindow(startMinutes: 420, endMinutes: 1020);
      expect(TimeWindow.fromJson(window.toJson()), window);
    });

    test('fromJson rejects a non-integer field', () {
      expect(
        () => TimeWindow.fromJson(const {
          'startMinutes': '480',
          'endMinutes': 600,
        }),
        throwsFormatException,
      );
    });

    test('compareTo orders by start, then end', () {
      final windows = [
        const TimeWindow(startMinutes: 600, endMinutes: 660),
        const TimeWindow(startMinutes: 480, endMinutes: 720),
        const TimeWindow(startMinutes: 480, endMinutes: 600),
      ]..sort();

      expect(windows, const [
        TimeWindow(startMinutes: 480, endMinutes: 600),
        TimeWindow(startMinutes: 480, endMinutes: 720),
        TimeWindow(startMinutes: 600, endMinutes: 660),
      ]);
    });

    test('windowsContain is true when any window fits the span', () {
      const windows = [
        TimeWindow(startMinutes: 480, endMinutes: 600),
        TimeWindow(startMinutes: 960, endMinutes: 1080),
      ];

      expect(windowsContain(windows, start: 990, end: 1050), isTrue);
      expect(windowsContain(windows, start: 720, end: 780), isFalse);
      expect(windowsContain(const [], start: 480, end: 540), isFalse);
    });

    test('timeWindowListEquals compares element by element, in order', () {
      const a = [TimeWindow(startMinutes: 480, endMinutes: 600)];
      const b = [TimeWindow(startMinutes: 480, endMinutes: 600)];
      const c = [TimeWindow(startMinutes: 480, endMinutes: 660)];

      expect(timeWindowListEquals(a, b), isTrue);
      expect(timeWindowListEquals(a, c), isFalse);
      expect(timeWindowListEquals(a, const []), isFalse);
    });
  });
}
