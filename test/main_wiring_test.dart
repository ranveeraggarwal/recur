import 'package:flutter_test/flutter_test.dart';
import 'package:recur/calendar/device_calendar_gateway.dart';
import 'package:recur/calendar/fake_calendar_gateway.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/main.dart';

void main() {
  group('buildDependencies', () {
    test('uses DeviceCalendarGateway by default', () {
      final deps = buildDependencies(
        store: InMemoryLocalStore(),
        useFakeCalendar: false,
      );

      expect(deps.calendar, isA<DeviceCalendarGateway>());
    });

    test('uses FakeCalendarGateway when useFakeCalendar is true', () {
      final deps = buildDependencies(
        store: InMemoryLocalStore(),
        useFakeCalendar: true,
      );

      expect(deps.calendar, isA<FakeCalendarGateway>());
    });
  });
}
