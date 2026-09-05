import 'package:flutter/widgets.dart';

import 'calendar/calendar_gateway.dart';
import 'core/clock.dart';
import 'core/id_generator.dart';
import 'data/booking_repository.dart';
import 'data/event_type_repository.dart';
import 'data/settings_repository.dart';
import 'places/places_gateway.dart';

/// Everything a screen needs, injected once at the root. See
/// `docs/architecture.md`, section "App wiring".
final class AppDependencies {
  const AppDependencies({
    required this.clock,
    required this.ids,
    required this.eventTypes,
    required this.bookings,
    required this.settings,
    required this.calendar,
    required this.places,
  });

  final Clock clock;
  final IdGenerator ids;
  final EventTypeRepository eventTypes;
  final BookingRepository bookings;
  final SettingsRepository settings;
  final CalendarGateway calendar;
  final PlacesGateway places;
}

/// Makes [AppDependencies] available to every descendant of [RecurApp].
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.deps, required super.child});

  final AppDependencies deps;

  /// Returns the [AppDependencies] injected above [context]. Throws a
  /// [FlutterError] if no [AppScope] is found.
  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw FlutterError(
        'AppScope.of() called with a context that does not contain an '
        'AppScope.\n'
        'No AppScope ancestor could be found starting from the context that '
        'was passed to AppScope.of(). This usually happens when the context '
        'used comes from a widget above the AppScope.',
      );
    }
    return scope.deps;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => deps != oldWidget.deps;
}
