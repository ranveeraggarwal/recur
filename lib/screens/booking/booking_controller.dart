// The named `deps` parameter can't share its name with the private `_deps`
// field, so it can't become an initializing formal.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../core/local_date.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/booking.dart';
import '../../data/models/event_type.dart';
import '../../suggestions/slot_grid.dart';
import '../../suggestions/suggestion_engine.dart';
import '../../suggestions/suggestion_window.dart';

/// Drives the Booking screen: the displayed week, the per-day slot grids,
/// the selected slot, and (from #23) confirming a booking.
///
/// See `docs/architecture.md`, section "BookingController".
class BookingController extends ChangeNotifier {
  BookingController({required this.eventType, required AppDependencies deps})
    : _deps = deps;

  final EventType eventType;
  final AppDependencies _deps;

  /// Loaded in [init].
  CalendarAccess access = CalendarAccess.notDetermined;

  /// Whether the phone has at least one writable calendar. Loaded in
  /// [init]; `false` means "No writable calendar found."
  bool hasWritableCalendar = false;

  List<CalendarInfo> _writableCalendars = const [];
  AppSettings _settings = AppSettings.empty;
  SuggestionWindow _window = const SuggestionWindow(
    weekdays: {},
    startMinutes: 360,
    endMinutes: 1320,
  );

  bool _initialized = false;
  bool get initialized => _initialized;

  /// Today, fixed at [init] time via the app's [Clock].
  late LocalDate today;

  /// The Monday of the displayed week.
  late LocalDate weekMonday;

  /// Defaults to [today].
  late LocalDate selectedDate;

  Slot? selectedSlot;

  /// One entry per day of the displayed week.
  Map<LocalDate, List<Slot>> grids = {};

  bool isConfirming = false;

  /// Loads access, writable calendars, settings, and the current week.
  Future<void> init() async {
    today = LocalDate.fromDateTime(_deps.clock.now());
    weekMonday = today.mondayOfWeek;
    selectedDate = today;

    access = await _deps.calendar.checkAccess();
    await _refreshCalendars();
    _settings = await _deps.settings.get();

    if (access == CalendarAccess.granted) {
      await _refreshWindow();
      await showWeek(weekMonday);
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _refreshCalendars() async {
    _writableCalendars = await _deps.calendar.listWritableCalendars();
    hasWritableCalendar = _writableCalendars.isNotEmpty;
  }

  Future<void> _refreshWindow() async {
    final bookings = await _deps.bookings.getForEventType(eventType.id);
    _window = suggestionWindowFor(
      eventType: eventType,
      bookings: bookings,
      now: _deps.clock.now(),
    );
  }

  Future<void> requestAccess() async {
    access = await _deps.calendar.requestAccess();
    if (access == CalendarAccess.granted) {
      await _refreshCalendars();
      await _refreshWindow();
      await showWeek(weekMonday);
    }
    notifyListeners();
  }

  Future<void> openSettings() async {
    await _deps.calendar.openSystemSettings();
  }

  /// Fetches busy intervals for `[monday 00:00, monday+7 00:00)` and
  /// rebuilds [grids]. Clears [selectedDate]/[selectedSlot] back to
  /// [monday] when they fall outside the newly displayed week.
  Future<void> showWeek(LocalDate monday) async {
    weekMonday = monday;
    final weekEnd = monday.addDays(6);

    final busy = await _deps.calendar.busyIntervals(
      from: monday.at(0),
      to: monday.addDays(7).at(0),
    );

    final newGrids = <LocalDate, List<Slot>>{};
    for (var i = 0; i < 7; i++) {
      final date = monday.addDays(i);
      newGrids[date] = buildSlotGrid(
        date: date,
        durationMinutes: eventType.durationMinutes,
        window: _window,
        busy: busy,
        now: _deps.clock.now(),
      );
    }
    grids = newGrids;

    if (selectedDate.compareTo(monday) < 0 ||
        selectedDate.compareTo(weekEnd) > 0) {
      selectedDate = monday;
    }
    final slot = selectedSlot;
    if (slot != null &&
        (slot.date.compareTo(monday) < 0 || slot.date.compareTo(weekEnd) > 0)) {
      selectedSlot = null;
    }

    notifyListeners();
  }

  void selectDate(LocalDate date) {
    selectedDate = date;
    notifyListeners();
  }

  void toggleSlot(Slot slot) {
    final current = selectedSlot;
    final isSameSlot =
        current != null &&
        current.date == slot.date &&
        current.startMinutes == slot.startMinutes;
    selectedSlot = isSameSlot ? null : slot;
    if (!isSameSlot) {
      selectedDate = slot.date;
    }
    notifyListeners();
  }

  /// The selected calendar id if it is still writable, else the only
  /// writable calendar's id, else `null` (a calendar must be chosen).
  String? get calendarIdToUse {
    final selected = _settings.selectedCalendarId;
    if (selected != null && _writableCalendars.any((c) => c.id == selected)) {
      return selected;
    }
    if (_writableCalendars.length == 1) {
      return _writableCalendars.single.id;
    }
    return null;
  }

  /// Writes the calendar event, then logs the booking. See
  /// `docs/architecture.md`'s "BookingController" section for the ordering
  /// and error-handling contract.
  Future<Booking> confirm({required String calendarId}) async {
    // TODO(#23): calendar.createEvent(...) then bookings.add(...).
    throw UnimplementedError('confirm() lands in #23.');
  }
}
