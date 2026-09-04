import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_scope.dart';
import 'calendar/fake_calendar_gateway.dart';
import 'core/clock.dart';
import 'core/id_generator.dart';
import 'data/booking_repository.dart';
import 'data/event_type_repository.dart';
import 'data/json_file_local_store.dart';
import 'data/settings_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final documentsDir = await getApplicationDocumentsDirectory();
  final root = Directory('${documentsDir.path}/recur');
  final store = JsonFileLocalStore(root);

  final deps = AppDependencies(
    clock: SystemClock(),
    ids: UuidLikeIdGenerator(),
    eventTypes: LocalEventTypeRepository(store),
    bookings: LocalBookingRepository(store),
    settings: LocalSettingsRepository(store),
    // Until M7 lands, main.dart uses FakeCalendarGateway() unconditionally.
    calendar: FakeCalendarGateway(),
  );

  runApp(AppScope(deps: deps, child: const RecurApp()));
}
