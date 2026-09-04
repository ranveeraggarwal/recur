# Recur - architecture

This document is enough to build the app without any other context. Where
a choice was open, the decision is recorded in the "Decisions" section at
the end. Issues quote this file; if they disagree, this file wins.

## Toolchain

| Item | Value |
| --- | --- |
| Flutter | 3.47.2 stable (Dart 3.13.2), pinned in `.github/workflows/ci.yml` |
| Android | package `com.ranveeraggarwal.recur`, minSdk 24, targetSdk 35, compileSdk from Flutter |
| Java for Gradle | 17 |
| Calendar plugin | `device_calendar_plus` ^0.8.0 (pub.dev, published 2026-07-23) |
| Lints | `flutter_lints`, `flutter analyze --fatal-infos` must be clean |
| Tests | `flutter test`, run with `TZ=Europe/Stockholm` |

Validation commands every issue uses:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
TZ=Europe/Stockholm flutter test
flutter build apk --debug
```

## Layers

```
lib/
  main.dart                     composition root (real adapters)
  app.dart                      RecurApp: MaterialApp + theme + routes
  core/
    clock.dart                  Clock interface + SystemClock + FixedClock
    id_generator.dart           IdGenerator interface + UuidLikeIdGenerator + SequentialIdGenerator
    local_date.dart             LocalDate value type (y/m/d, no time zone)
    time_of_day_minutes.dart    helpers for minutes-of-day <-> "HH:mm"
    formatting.dart             date/time/duration/relative-time formatting used by UI
  data/
    models/
      event_type.dart           EventType
      booking.dart              Booking
      app_settings.dart         AppSettings
    local_store.dart            LocalStore interface + InMemoryLocalStore
    json_file_local_store.dart  JsonFileLocalStore (path_provider)
    event_type_repository.dart  EventTypeRepository interface + LocalEventTypeRepository
    booking_repository.dart     BookingRepository interface + LocalBookingRepository
    settings_repository.dart    SettingsRepository interface + LocalSettingsRepository
  calendar/
    calendar_gateway.dart       CalendarGateway interface + value types
    fake_calendar_gateway.dart  FakeCalendarGateway (used by every screen test)
    device_calendar_gateway.dart  DeviceCalendarGateway (the only file importing device_calendar_plus)
  suggestions/
    suggestion_window.dart      SuggestionWindow value type
    suggestion_engine.dart      suggestionWindowFor(...)
    slot_grid.dart              Slot, SlotState, buildSlotGrid(...)
  theme/
    tokens.dart                 RecurColors, RecurRadii, RecurShadows, RecurSpacing, RecurText
    app_theme.dart              ThemeData built from tokens
  widgets/
    event_card.dart
    duration_pill.dart
    day_pill.dart
    slot_tile.dart
    confirm_button.dart
    recur_text_field.dart
    recur_fab.dart
  screens/
    home/home_screen.dart
    editor/editor_screen.dart
    editor/editor_controller.dart
    booking/booking_screen.dart
    booking/booking_controller.dart
    booking/day_strip.dart
    booking/timeline.dart
    booking/confirmation_sheet.dart
    booking/calendar_picker_sheet.dart
  app_scope.dart                AppScope InheritedWidget holding the dependencies
test/
  helpers/
    golden.dart                 pumpGolden(), loadAppFonts(), 380px viewport
    fakes.dart                  shared fake wiring for widget tests
  goldens/                      *.png golden files
  ...one test file per source file, mirrored path
assets/fonts/                   Outfit-Regular.ttf, Outfit-Medium.ttf, Outfit-SemiBold.ttf, OFL.txt
```

Dependency direction: `screens` -> `widgets`, `suggestions`, `data`,
`calendar` interfaces. `suggestions` depends only on `core` and the calendar
value types. `data` depends only on `core`. Nothing outside
`calendar/device_calendar_gateway.dart` imports `device_calendar_plus`.

## Dependencies

Allowed pub dependencies for v1. Do not add others without changing this
list.

| Package | Purpose | Where |
| --- | --- | --- |
| `device_calendar_plus` ^0.8.0 | phone calendar | `calendar/device_calendar_gateway.dart` only |
| `path_provider` | app documents directory for the JSON store | `data/json_file_local_store.dart` only |
| `flutter_lints` (dev) | lints | analysis_options |

No state-management package, no router package, no code generation, no
`intl` (formatting is hand-written for the fixed English strings we use),
no `uuid` (ids are generated in `core/id_generator.dart`).

## Core types

```dart
// core/clock.dart
abstract interface class Clock {
  DateTime now(); // local time
}
class SystemClock implements Clock { DateTime now() => DateTime.now(); }
class FixedClock implements Clock {
  FixedClock(this._now);
  DateTime _now;
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
  set now(DateTime value) => _now = value;
}

// core/id_generator.dart
abstract interface class IdGenerator { String next(); }
class UuidLikeIdGenerator implements IdGenerator {
  // 32 hex chars from Random.secure(); no package.
}
class SequentialIdGenerator implements IdGenerator {
  // "id-1", "id-2", ... for tests.
}

// core/local_date.dart
/// A calendar date with no time or zone. Comparable, hashable.
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);
  factory LocalDate.fromDateTime(DateTime dt) => LocalDate(dt.year, dt.month, dt.day);
  final int year, month, day;
  int get weekday; // 1 = Monday ... 7 = Sunday, same as DateTime.monday..sunday
  LocalDate addDays(int n);
  LocalDate get mondayOfWeek;
  /// Local wall-clock DateTime at [minutesOfDay] on this date.
  DateTime at(int minutesOfDay) =>
      DateTime(year, month, day, minutesOfDay ~/ 60, minutesOfDay % 60);
}

// core/time_of_day_minutes.dart
/// Minutes since midnight: 0..1440. 06:00 = 360, 22:00 = 1320.
const int dayStartMinutes = 6 * 60;   // 360
const int dayEndMinutes = 22 * 60;    // 1320
const int slotMinutes = 30;
const int slotsPerDay = 32;
String formatMinutes(int minutesOfDay); // "06:00", "21:30"
int minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute;
```

All time-of-day arithmetic in the app uses wall-clock minutes on a
`LocalDate`, never `DateTime.add` across days. This is what keeps the slot
grid correct on DST days (see "Time zones" below).

## Data model

```dart
// data/models/event_type.dart
final class EventType {
  final String id;
  final String name;              // 1..40 chars, trimmed
  final int durationMinutes;      // 5..480, multiple of 5
  final String? location;        // trimmed, null when empty, <= 80 chars
  final String? notes;           // trimmed, null when empty, <= 500 chars
  final Set<int> preferredWeekdays;   // subset of {1..7}, non-empty
  final int preferredStartMinutes;    // 360..1320, multiple of 30
  final int preferredEndMinutes;      // > preferredStartMinutes + durationMinutes - 1, <= 1320
  final DateTime createdAt;
  // copyWith, ==, hashCode, toJson, fromJson
}

// data/models/booking.dart
final class Booking {
  final String id;
  final String eventTypeId;
  final DateTime start;          // local wall-clock time of the appointment
  final DateTime end;            // start + duration
  final String calendarId;       // phone calendar written to
  final String calendarEventId;  // id returned by the gateway
  final DateTime createdAt;
  // ==, hashCode, toJson, fromJson
}

// data/models/app_settings.dart
final class AppSettings {
  final String? selectedCalendarId;
  static const empty = AppSettings(selectedCalendarId: null);
  // copyWith, ==, hashCode, toJson, fromJson
}
```

JSON shapes (stable; these are the on-disk format):

```json
{"id":"...","name":"PT session","durationMinutes":60,"location":"Kungsholmen","notes":null,
 "preferredWeekdays":[1,3,5],"preferredStartMinutes":480,"preferredEndMinutes":1080,
 "createdAt":"2026-09-04T10:00:00.000"}

{"id":"...","eventTypeId":"...","start":"2026-09-08T10:00:00.000","end":"2026-09-08T11:00:00.000",
 "calendarId":"1","calendarEventId":"42","createdAt":"2026-09-04T10:00:00.000"}

{"selectedCalendarId":"1"}
```

`DateTime` values are serialised with `toIso8601String()` on a local
`DateTime` (no `Z`, no offset) and parsed with `DateTime.parse`, which
yields a local `DateTime` again. Bookings and event types are stored as
wall-clock times on purpose: an appointment is "Tuesday at 10:00", not an
instant.

## Persistence

```dart
// data/local_store.dart
/// A key -> JSON document store. Documents are whole JSON strings.
abstract interface class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String json);
  Future<void> delete(String key);
}
class InMemoryLocalStore implements LocalStore { /* Map<String,String> */ }

// data/json_file_local_store.dart
/// One file per key under <app documents dir>/recur/<key>.json.
/// Writes go to <key>.json.tmp then rename, so a crash never leaves a half file.
class JsonFileLocalStore implements LocalStore { JsonFileLocalStore(Directory root); }
```

Keys: `event_types` (JSON array of EventType), `bookings` (JSON array of
Booking), `settings` (AppSettings object).

Repositories are the only things that touch `LocalStore`. They load the
whole document, mutate, and write it back. Data volumes are tiny (tens of
cards, hundreds of bookings), so no database.

```dart
// data/event_type_repository.dart
abstract interface class EventTypeRepository {
  Future<List<EventType>> getAll();           // sorted by createdAt ascending
  Future<EventType?> getById(String id);
  Future<void> upsert(EventType eventType);
  Future<void> delete(String id);             // no-op if missing
}

// data/booking_repository.dart
abstract interface class BookingRepository {
  Future<List<Booking>> getForEventType(String eventTypeId); // sorted by start descending
  Future<Booking?> latestForEventType(String eventTypeId);   // by start, any (past or future)
  Future<void> add(Booking booking);
  Future<void> deleteForEventType(String eventTypeId);
}

// data/settings_repository.dart
abstract interface class SettingsRepository {
  Future<AppSettings> get();
  Future<void> save(AppSettings settings);
}
```

Each repository has one `Local*Repository` implementation over `LocalStore`.
Tests use `InMemoryLocalStore`. `JsonFileLocalStore` is tested with a temp
directory (`Directory.systemTemp.createTemp`).

## Calendar gateway

The app never talks to the plugin directly. It talks to this interface, and
every screen and test uses `FakeCalendarGateway`.

```dart
// calendar/calendar_gateway.dart
enum CalendarAccess {
  /// Read and write granted.
  granted,
  /// Not asked yet, or asked and can ask again. requestAccess() shows the dialog.
  notDetermined,
  /// The system dialog can no longer be shown. openSystemSettings() is the only way out.
  denied,
}

final class CalendarInfo {
  final String id;
  final String name;
  final String? accountName;
  final bool isPrimary;
  // ==, hashCode
}

/// A half-open interval [start, end) in local time that blocks slots.
final class BusyInterval {
  final DateTime start;
  final DateTime end;
  final String? title;   // null -> UI shows "Busy"
  // ==, hashCode
}

abstract interface class CalendarGateway {
  Future<CalendarAccess> checkAccess();
  Future<CalendarAccess> requestAccess();
  Future<void> openSystemSettings();

  /// Calendars the app may write to. Read-only and hidden calendars are excluded.
  Future<List<CalendarInfo>> listWritableCalendars();

  /// Busy intervals from every readable calendar, overlapping [from, to).
  /// Recurring events are expanded. All-day events and events with
  /// availability "free" are excluded. Requires access == granted.
  Future<List<BusyInterval>> busyIntervals({required DateTime from, required DateTime to});

  /// Creates one timed, non-recurring event. Returns the calendar event id.
  /// Throws CalendarWriteException on failure.
  Future<String> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? location,
    String? notes,
  });
}

class CalendarWriteException implements Exception {
  CalendarWriteException(this.message, [this.cause]);
  final String message; final Object? cause;
}
```

### FakeCalendarGateway

```dart
// calendar/fake_calendar_gateway.dart
class FakeCalendarGateway implements CalendarGateway {
  CalendarAccess access = CalendarAccess.granted;
  /// What requestAccess() will return (and set access to).
  CalendarAccess accessAfterRequest = CalendarAccess.granted;
  int requestAccessCalls = 0;
  int openSystemSettingsCalls = 0;
  List<CalendarInfo> calendars = [CalendarInfo(id: 'cal-1', name: 'Personal', accountName: 'me@example.com', isPrimary: true)];
  final List<BusyInterval> busy = [];
  /// Every createEvent call, in order.
  final List<CreatedEvent> created = [];
  /// If set, the next createEvent throws CalendarWriteException with this message and then clears.
  String? failNextCreateWith;

  // busyIntervals filters `busy` by overlap with [from, to) and also includes
  // events created via createEvent (so a booking blocks its own slot afterwards).
  // createEvent returns 'evt-1', 'evt-2', ...
  // busyIntervals and createEvent throw StateError if access != granted.
}

final class CreatedEvent {
  final String id, calendarId, title; final DateTime start, end; final String? location, notes;
}
```

### DeviceCalendarGateway (real adapter, M7)

Wraps `DeviceCalendar.instance` from `device_calendar_plus` 0.8.0. Mapping:

| Gateway | Plugin |
| --- | --- |
| `checkAccess()` | `hasPermissions()`; `granted` -> granted; `notDetermined`, `writeOnly` -> notDetermined; `denied`, `restricted` -> denied |
| `requestAccess()` | `requestPermissions(level: CalendarAccessLevel.full)`, same mapping |
| `openSystemSettings()` | `openAppSettings()` |
| `listWritableCalendars()` | `listCalendars()` filtered `!readOnly && !hidden`, mapped id/name/accountName/isPrimary |
| `busyIntervals(from, to)` | `listEvents(from, to)` (all calendars); drop `isAllDay`, drop `availability == EventAvailability.free`; map `startDate`/`endDate`/`title` (empty title -> null) |
| `createEvent(...)` | `createEvent(calendarId:, title:, startDate:, endDate:, location:, description: notes)`; wrap `DeviceCalendarException` and `PlatformException` in `CalendarWriteException` |

`autoPermissions` on the plugin stays `null`; the app drives permission
explicitly through `requestAccess()`.

Android manifest needs:

```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
```

The mapping functions (`accessFromStatus`, `calendarInfoFrom`,
`busyIntervalFrom`) are top-level pure functions so they can be unit tested
with plugin value objects, which have public constructors. Calls into
`DeviceCalendar.instance` are not unit tested; they are covered by the
on-device checklist.

## Suggestion engine

```dart
// suggestions/suggestion_window.dart
final class SuggestionWindow {
  final Set<int> weekdays;    // 1..7
  final int startMinutes;     // 360..1320
  final int endMinutes;       // startMinutes..1320
}

// suggestions/suggestion_engine.dart
/// [bookings] may be in any order and may include future bookings; the
/// function filters to bookings with start < now.
SuggestionWindow suggestionWindowFor({
  required EventType eventType,
  required List<Booking> bookings,
  required DateTime now,
});
```

Algorithm, exactly:

1. `past = bookings.where((b) => b.start.isBefore(now))`, sorted by `start`
   descending.
2. If `past.length < 3`: return `SuggestionWindow(weekdays:
   eventType.preferredWeekdays, startMinutes: eventType.preferredStartMinutes,
   endMinutes: eventType.preferredEndMinutes)`.
3. `recent = past.take(3)`.
4. Count weekdays (`b.start.weekday`) across `recent`. `weekdays` = every
   weekday whose count equals the maximum count. (Three different weekdays
   -> all three. Two the same, one different -> the pair's weekday only.)
5. `earliest = min(minutesOfDay(b.start))`, `latest =
   max(minutesOfDay(b.end))` across `recent`. If a booking's `end` is on a
   later date than its `start` (it crossed midnight), treat its end as 1440.
6. `startMinutes = max(360, earliest - 30)`, `endMinutes = min(1320, latest
   + 30)`.
7. If `endMinutes < startMinutes + eventType.durationMinutes` (window too
   small after clamping), keep the values anyway; the grid will simply
   highlight nothing on those days. Do not fall back to the preference.

```dart
// suggestions/slot_grid.dart
enum SlotState { available, highlighted, blocked }
enum BlockReason { past, conflict, outsideHours }

final class Slot {
  final LocalDate date;
  final int startMinutes;          // 360, 390, ... 1290
  final int endMinutes;            // startMinutes + durationMinutes (may exceed 1320 only when blocked outsideHours)
  final SlotState state;
  final BlockReason? blockReason;  // non-null iff state == blocked
  final String? blockingTitle;     // title of the first overlapping busy interval, if conflict
  DateTime get start => date.at(startMinutes);
}

/// Builds the 32 slots for [date].
List<Slot> buildSlotGrid({
  required LocalDate date,
  required int durationMinutes,
  required SuggestionWindow window,
  required List<BusyInterval> busy,
  required DateTime now,
});
```

For each `startMinutes` in 360, 390, ..., 1290:

1. `endMinutes = startMinutes + durationMinutes`.
2. Past: `!date.at(startMinutes).isAfter(now)` -> blocked, `past`.
3. Outside hours: `endMinutes > 1320` -> blocked, `outsideHours`.
4. Conflict: any `b` in `busy` with `b.start < slotEnd && b.end > slotStart`
   where `slotStart = date.at(startMinutes)` and `slotEnd =
   date.at(endMinutes)` -> blocked, `conflict`, `blockingTitle = b.title` of
   the earliest-starting overlapping interval.
5. Highlighted: `window.weekdays.contains(date.weekday) && startMinutes >=
   window.startMinutes && endMinutes <= window.endMinutes`.
6. Else available.

Order of precedence: past, outsideHours, conflict, highlighted, available.

Busy intervals are compared as `DateTime` instants. Slot boundaries are
built with `LocalDate.at`, which constructs a local wall-clock `DateTime`.
The engine has no notion of "week"; the Booking screen calls
`buildSlotGrid` once per visible day.

## Time zones and DST

- All times shown and stored are local wall-clock times. The phone's zone is
  whatever it is; the app never converts.
- Slot boundaries come from `LocalDate.at(minutes)` = `DateTime(y, m, d, h,
  min)`. On a DST day (Stockholm: last Sunday of March, 02:00 -> 03:00; last
  Sunday of October, 03:00 -> 02:00) the 06:00 to 22:00 range is unaffected
  because the transition is at 02:00/03:00, but code that did `dayStart.add(
  Duration(minutes: n))` from midnight would be off by an hour. That is why
  nothing may add a `Duration` to a midnight `DateTime` to reach a slot.
- `Booking.end` is `date.at(endMinutes)`, not `start.add(duration)`.
- Tests that depend on DST run under `TZ=Europe/Stockholm` (CI sets it). A
  test that needs it checks at load time and marks itself skipped with the
  reason `Run with TZ=Europe/Stockholm` when the zone is wrong, so local
  runs in other zones do not fail confusingly.

## App wiring

```dart
// app_scope.dart
final class AppDependencies {
  final Clock clock;
  final IdGenerator ids;
  final EventTypeRepository eventTypes;
  final BookingRepository bookings;
  final SettingsRepository settings;
  final CalendarGateway calendar;
}

/// InheritedWidget. AppScope.of(context) returns the AppDependencies.
class AppScope extends InheritedWidget { ... }
```

`main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = Directory('${(await getApplicationDocumentsDirectory()).path}/recur');
  final store = JsonFileLocalStore(root);
  final deps = AppDependencies(
    clock: SystemClock(),
    ids: UuidLikeIdGenerator(),
    eventTypes: LocalEventTypeRepository(store),
    bookings: LocalBookingRepository(store),
    settings: LocalSettingsRepository(store),
    calendar: const bool.fromEnvironment('USE_FAKE_CALENDAR')
        ? FakeCalendarGateway()      // flutter run --dart-define=USE_FAKE_CALENDAR=true
        : DeviceCalendarGateway(),
  );
  runApp(AppScope(deps: deps, child: const RecurApp()));
}
```

Until M7 lands, `main.dart` uses `FakeCalendarGateway()` unconditionally.

Navigation is plain `Navigator.push` with `MaterialPageRoute`. Routes:

| From | Action | To |
| --- | --- | --- |
| Home | tap card | `BookingScreen(eventTypeId)` |
| Home | long-press card | `EditorScreen(eventTypeId)` |
| Home | FAB | `EditorScreen(null)` |
| Home | calendar icon (2+ writable calendars) | `CalendarPickerSheet` (showModalBottomSheet) |
| Editor | Save / Delete | pop with `true` so Home reloads |
| Booking | Confirm ok | `ConfirmationSheet`; on dismiss pop Booking |

State: each screen has a `ChangeNotifier` controller
(`EditorController`, `BookingController`) constructed in the screen's
`State.initState` from `AppScope.of(context)` and disposed with it. Home is
simple enough to load in `initState` and hold a `Future`. No global state.

### BookingController

```dart
class BookingController extends ChangeNotifier {
  BookingController({required this.eventType, required AppDependencies deps});

  CalendarAccess access;            // loaded in init()
  bool hasWritableCalendar;         // false -> "No writable calendar found."
  LocalDate weekMonday;             // Monday of the displayed week
  LocalDate selectedDate;           // defaults to today
  Slot? selectedSlot;
  Map<LocalDate, List<Slot>> grids; // one entry per day of the displayed week
  bool isConfirming;

  Future<void> init();              // checkAccess, listWritableCalendars, load bookings, build window, loadWeek
  Future<void> requestAccess();
  Future<void> openSettings();
  Future<void> showWeek(LocalDate monday);   // fetch busy for [monday 00:00, monday+7 00:00), rebuild grids
  void selectDate(LocalDate d);
  void toggleSlot(Slot s);
  /// Returns null if a calendar must be chosen first (2+ writable, none selected).
  /// Otherwise writes the event, logs the booking, returns the Booking.
  Future<Booking> confirm({required String calendarId});
  String? get calendarIdToUse;      // selected id if valid, else the only writable calendar's id, else null
}
```

`confirm` order: `calendar.createEvent(...)` first, then
`bookings.add(...)`. If the calendar write throws, nothing is logged and the
exception propagates to the screen, which shows the snack bar. If the
booking log fails after the event was written, the event stays in the
calendar (we never delete events) and the error propagates; this is
accepted for v1.

Event written: `title = eventType.name`, `location = eventType.location`,
`notes = eventType.notes`, `start = slot.start`, `end =
slot.date.at(slot.endMinutes)`.

## Formatting (core/formatting.dart)

Fixed English, hand-written, no `intl`:

| Function | Example |
| --- | --- |
| `formatDuration(45)` | `45 min` |
| `formatTime(600)` | `10:00` |
| `formatDayShort(LocalDate)` | `Tue 8 Sep` |
| `formatWeekOf(LocalDate monday)` | `Week of 7 Sep` |
| `formatSlotSummary(Slot)` | `Tue 8 Sep, 10:00 to 11:00` |
| `formatLastBooked(Booking? latest, DateTime now)` | `Not booked yet`, `Last booked today`, `Last booked yesterday`, `Last booked 3 days ago`, `Last booked 3 weeks ago` (7..27 days -> weeks), `Last booked 2 months ago` (28+ days, 30-day months), `Booked for Tue 8 Sep` (start in the future) |

Weekday abbreviations: `Mon Tue Wed Thu Fri Sat Sun`. Month abbreviations:
`Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec`.

## Testing strategy

- Unit tests for `core`, `data`, `suggestions`, and the pure mapping
  functions in `calendar`.
- Widget tests for every widget and screen, always with
  `FakeCalendarGateway`, `InMemoryLocalStore`, `FixedClock`, and
  `SequentialIdGenerator`.
- Golden tests for every widget and screen at a 380 px wide viewport,
  device pixel ratio 1.0, with the Outfit font loaded
  (`test/helpers/golden.dart`). Golden files live in `test/goldens/` and are
  generated on Linux (`flutter test --update-goldens`), which is what CI
  compares against.
- The Stockholm DST week test lives in `test/suggestions/slot_grid_test.dart`
  and is skipped, with a reason, when `TZ` is not `Europe/Stockholm`.
- No test touches `device_calendar_plus`.

`test/helpers/golden.dart`:

```dart
const goldenWidth = 380.0;

Future<void> loadAppFonts() async {
  // Load assets/fonts/Outfit-*.ttf from disk via FontLoader('Outfit') once.
}

/// Sets the view to 380 x [height] logical px at DPR 1, wraps [child] in
/// RecurApp's theme + a Scaffold when [scaffold] is true, pumps, and settles.
Future<void> pumpGolden(WidgetTester tester, Widget child, {double height = 800, bool scaffold = true});

/// expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'))
Future<void> expectGolden(WidgetTester tester, String name);
```

## Decisions

Each of these was open and is now fixed. Change one only by editing this
file and saying so in the commit.

| # | Decision | Why |
| --- | --- | --- |
| D1 | No state-management or router package; `ChangeNotifier` controllers and `Navigator.push`. | Four screens. Fewer concepts for small agents. |
| D2 | Persistence is JSON files via `path_provider`, one file per key, atomic rename on write. | Tiny data. No native DB dependency, trivially fakeable. |
| D3 | Times are stored and shown as local wall-clock; slot maths uses `LocalDate.at(minutes)`, never `Duration` adds from midnight. | Correct on DST days. Appointments are wall-clock things. |
| D4 | "Past bookings" for suggestions means `start < now`; the 3 most recent by `start`. | Matches "last 3 bookings" as a person would read it. |
| D5 | Suggestion weekday ties include all tied weekdays. Window pad is 30 min each side, clamped 06:00 to 22:00. Too-small windows are kept, not replaced. | As specified; keeping the window avoids surprising fallbacks. |
| D6 | Slot precedence: past, outside hours, conflict, highlighted, available. Slots whose appointment would end after 22:00 are blocked. | Timeline ends at 22:00; nothing may be booked that cannot be drawn. |
| D7 | Conflicts come from all readable calendars. All-day events and `free` events never block. Overlap is half-open. | Birthdays should not block a whole day; back-to-back is fine. |
| D8 | Only `createEvent` is used on the plugin. No update, delete, reminders, recurrence, or native UI. | Scope. |
| D9 | The chosen calendar is stored by id. If the stored id is no longer writable it is ignored; if exactly one writable calendar exists it is used without asking. | No settings screen. |
| D10 | Deleting a card deletes its local bookings and never touches the calendar. | We never delete calendar events. |
| D11 | Golden tests at 380 px width, DPR 1, Outfit loaded from `assets/fonts`, generated on Linux. | Matches CI. |
| D12 | Formatting is hand-written English; no `intl`. | One language, a dozen strings. |
| D13 | Ids are 32 hex chars from `Random.secure()`; tests use `SequentialIdGenerator`. | No `uuid` dependency. |
| D14 | Flutter pinned to 3.47.2 in CI; `pubspec.yaml` keeps `sdk: ^3.13.2`. | Reproducible builds. |
| D15 | Confirm writes the calendar event first, then logs the booking. A failed log after a successful write is accepted for v1. | We cannot undo a calendar write without deleting events. |
| D16 | `flutter run --dart-define=USE_FAKE_CALENDAR=true` swaps in the fake at the composition root. | Lets the app run in an emulator without a calendar account. |
| D17 | Week navigation: Monday-to-Sunday weeks, cannot go earlier than the current week, no upper limit. | Nobody books in the past. |
| D18 | The Editor's duration pills are 30/45/60/90 plus Custom (5 to 480 in steps of 5). Default duration 60, default weekdays Mon to Fri, default window 08:00 to 18:00. | Sensible defaults for the target use. |
