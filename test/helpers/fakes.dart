import 'package:flutter/material.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/fake_calendar_gateway.dart';
import 'package:recur/core/clock.dart';
import 'package:recur/core/id_generator.dart';
import 'package:recur/data/booking_repository.dart';
import 'package:recur/data/event_type_repository.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/data/settings_repository.dart';
import 'package:recur/theme/app_theme.dart';

/// A default "now" for tests: Monday, 2026-09-07, 09:00.
final _defaultNow = DateTime(2026, 9, 7, 9, 0);

/// A fully faked [AppDependencies] for widget tests, plus direct handles to
/// the fakes underneath it so tests can seed data and poke behaviour.
class TestDeps {
  TestDeps({
    required this.deps,
    required this.calendar,
    required this.clock,
    required this.store,
  });

  final AppDependencies deps;
  final FakeCalendarGateway calendar;
  final FixedClock clock;
  final InMemoryLocalStore store;
}

/// Builds a [TestDeps] backed by [FixedClock] (default [_defaultNow], a
/// Monday), [SequentialIdGenerator], [InMemoryLocalStore], and a
/// [FakeCalendarGateway].
TestDeps buildTestDeps({DateTime? now}) {
  final clock = FixedClock(now ?? _defaultNow);
  final calendar = FakeCalendarGateway();
  final store = InMemoryLocalStore();

  final deps = AppDependencies(
    clock: clock,
    ids: SequentialIdGenerator(),
    eventTypes: LocalEventTypeRepository(store),
    bookings: LocalBookingRepository(store),
    settings: LocalSettingsRepository(store),
    calendar: calendar,
  );

  return TestDeps(deps: deps, calendar: calendar, clock: clock, store: store);
}

/// Wraps [home] in a [MaterialApp] using Recur's theme, with [deps] injected
/// through [AppScope], for widget tests that need `AppScope.of(context)`.
Widget wrapInApp(AppDependencies deps, Widget home) {
  return AppScope(
    deps: deps,
    child: MaterialApp(
      title: 'Recur',
      debugShowCheckedModeBanner: false,
      theme: buildRecurTheme(),
      home: home,
    ),
  );
}
