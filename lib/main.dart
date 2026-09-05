import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_scope.dart';
import 'calendar/device_calendar_gateway.dart';
import 'calendar/fake_calendar_gateway.dart';
import 'core/clock.dart';
import 'core/id_generator.dart';
import 'data/booking_repository.dart';
import 'data/event_type_repository.dart';
import 'data/json_file_local_store.dart';
import 'data/local_store.dart';
import 'data/settings_repository.dart';

/// Builds the app's [AppDependencies] on top of [store], swapping in
/// [FakeCalendarGateway] when [useFakeCalendar] is true and
/// [DeviceCalendarGateway] otherwise. Extracted from `main()` so it is
/// testable without `path_provider`. See `docs/architecture.md`, section
/// "App wiring".
AppDependencies buildDependencies({
  required LocalStore store,
  required bool useFakeCalendar,
}) {
  return AppDependencies(
    clock: SystemClock(),
    ids: UuidLikeIdGenerator(),
    eventTypes: LocalEventTypeRepository(store),
    bookings: LocalBookingRepository(store),
    settings: LocalSettingsRepository(store),
    calendar: useFakeCalendar ? FakeCalendarGateway() : DeviceCalendarGateway(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final documentsDir = await getApplicationDocumentsDirectory();
  final root = Directory('${documentsDir.path}/recur');
  final store = JsonFileLocalStore(root);

  const useFakeCalendar = bool.fromEnvironment(
    'USE_FAKE_CALENDAR',
    defaultValue: false,
  );
  final deps = buildDependencies(
    store: store,
    useFakeCalendar: useFakeCalendar,
  );

  runApp(AppScope(deps: deps, child: const RecurApp()));
}
