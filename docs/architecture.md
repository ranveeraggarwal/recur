# Architecture

How Recur is built. Open choices are settled in the table at the end.

## Toolchain

Flutter 3.47.2 stable (Dart 3.13.2). Android minSdk 24, targetSdk 35.
Java 17 for Gradle. Calendar plugin `device_calendar_plus` ^0.8.0.

Checks that must pass before any push:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
TZ=Europe/Stockholm flutter test
flutter build apk --debug
```

## Layout

```
lib/
  main.dart            builds the real dependencies
  app.dart             RecurApp (MaterialApp + theme)
  app_scope.dart       AppScope InheritedWidget holding AppDependencies
  core/                Clock, IdGenerator, LocalDate, minutes helpers, formatting
  data/                models + LocalStore + repositories
  calendar/            CalendarGateway, FakeCalendarGateway, DeviceCalendarGateway
  suggestions/         suggestionWindowFor, buildSlotGrid
  theme/               tokens.dart, app_theme.dart
  widgets/             EventCard, DurationPill, DayPill, SlotTile, ConfirmButton, RecurTextField, RecurFab
  screens/             home/, editor/, booking/
test/                  mirrors lib/; helpers/ and goldens/
assets/fonts/          Outfit 400/500/600 + OFL.txt
```

Only `calendar/device_calendar_gateway.dart` imports the plugin. Every
screen and every test uses `FakeCalendarGateway`.

Dependencies allowed: `device_calendar_plus`, `path_provider`, and
`flutter_lints`. Nothing else.

## Time

Everything is local wall-clock time. Minutes since midnight are the unit for
times of day: 06:00 is 360, 22:00 is 1320, a slot is 30.

```dart
class LocalDate {            // a date with no time or zone
  int year, month, day;
  int get weekday;           // 1 Monday .. 7 Sunday
  LocalDate addDays(int n);
  LocalDate get mondayOfWeek;
  DateTime at(int minutes) => DateTime(year, month, day, minutes ~/ 60, minutes % 60);
}
```

Slot times always come from `LocalDate.at`. Never add a `Duration` to
midnight to reach a time of day; on a DST day that is an hour off. Tests
that care run with `TZ=Europe/Stockholm` and skip themselves elsewhere.

Also in `core/`: `Clock` (`SystemClock`, `FixedClock`), `IdGenerator`
(`UuidLikeIdGenerator`, `SequentialIdGenerator`), and `formatting.dart`
with hand-written English: `45 min`, `10:00`, `Tue 8 Sep`, `Week of 7 Sep`,
`Tue 8 Sep, 10:00 to 11:00`, `Last booked 3 weeks ago`, `Booked for Tue 8
Sep`, `Not booked yet`.

## Data

```dart
class EventType {
  String id, name;                 // name 1..40 chars
  int durationMinutes;             // 5..480, step 5
  String? location, notes;         // <= 80 / <= 500 chars
  Set<int> preferredWeekdays;      // 1..7, not empty
  int preferredStartMinutes;       // 360..1320, step 30
  int preferredEndMinutes;         // >= start + duration, <= 1320
  DateTime createdAt;
}

class Booking {
  String id, eventTypeId, calendarId, calendarEventId;
  DateTime start, end, createdAt;
}

class AppSettings { String? selectedCalendarId; }
```

Stored as JSON files, one per key (`event_types`, `bookings`, `settings`),
under the app documents directory. Writes go to a temp file then rename.
`DateTime` is written with `toIso8601String()` (local, no `Z`).

```dart
abstract interface class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String json);
  Future<void> delete(String key);
}
// InMemoryLocalStore for tests, JsonFileLocalStore(Directory) for the app.

abstract interface class EventTypeRepository {
  Future<List<EventType>> getAll();            // by createdAt
  Future<EventType?> getById(String id);
  Future<void> upsert(EventType e);
  Future<void> delete(String id);
}
abstract interface class BookingRepository {
  Future<List<Booking>> getForEventType(String id);   // newest first
  Future<Booking?> latestForEventType(String id);
  Future<void> add(Booking b);
  Future<void> deleteForEventType(String id);
}
abstract interface class SettingsRepository {
  Future<AppSettings> get();
  Future<void> save(AppSettings s);
}
```

## Calendar

```dart
enum CalendarAccess { granted, notDetermined, denied }   // denied = only settings can fix it

class CalendarInfo { String id, name; String? accountName; bool isPrimary; }
class BusyInterval { DateTime start, end; String? title; }   // half-open [start, end)

abstract interface class CalendarGateway {
  Future<CalendarAccess> checkAccess();
  Future<CalendarAccess> requestAccess();
  Future<void> openSystemSettings();
  Future<List<CalendarInfo>> listWritableCalendars();
  Future<List<BusyInterval>> busyIntervals({required DateTime from, required DateTime to});
  Future<String> createEvent({required String calendarId, required String title,
      required DateTime start, required DateTime end, String? location, String? notes});
}
class CalendarWriteException implements Exception { String message; Object? cause; }
```

`busyIntervals` reads every calendar, expands recurring events, and drops
all-day and free events.

`FakeCalendarGateway` has public fields tests can set: `access`,
`accessAfterRequest`, `calendars`, `busy`, `created`, `failNextCreateWith`,
plus counters `requestAccessCalls` and `openSystemSettingsCalls`. Created
events show up as busy afterwards. Event ids are `evt-1`, `evt-2`, ...

`DeviceCalendarGateway` maps to the plugin: `hasPermissions` and
`requestPermissions(level: full)` (granted -> granted; notDetermined or
writeOnly -> notDetermined; denied or restricted -> denied),
`openAppSettings`, `listCalendars` minus read-only and hidden,
`listEvents(from, to)` minus all-day and free, and `createEvent` with
`description: notes`. Plugin errors become `CalendarWriteException`. The
manifest needs `READ_CALENDAR` and `WRITE_CALENDAR`.

## Suggestions

```dart
class SuggestionWindow { Set<int> weekdays; int startMinutes, endMinutes; }

SuggestionWindow suggestionWindowFor({required EventType eventType,
    required List<Booking> bookings, required DateTime now});
```

Past bookings are those with `start < now`. Fewer than 3: use the card's
preference. Otherwise take the 3 most recent by start. Weekdays: the most
common, ties keep all. Window: earliest start to latest end (an end past
midnight counts as 24:00), padded 30 minutes each side, clamped 360..1320.
A window too small for the duration is kept as is.

```dart
enum SlotState { available, highlighted, blocked }
enum BlockReason { past, conflict, outsideHours }

class Slot {
  LocalDate date; int startMinutes, endMinutes;
  SlotState state; BlockReason? blockReason; String? blockingTitle;
  DateTime get start => date.at(startMinutes);
}

List<Slot> buildSlotGrid({required LocalDate date, required int durationMinutes,
    required SuggestionWindow window, required List<BusyInterval> busy, required DateTime now});
```

32 slots, 360 to 1290 in steps of 30. Precedence: past (start not after
now), outside hours (end after 1320), conflict (overlaps a busy interval;
title of the earliest one), highlighted (weekday in window and the whole
appointment inside it), else available.

## Screens

`AppDependencies` holds `clock`, `ids`, `eventTypes`, `bookings`,
`settings`, `calendar`. `AppScope.of(context)` returns it. `main.dart`
builds the real set; `flutter run --dart-define=USE_FAKE_CALENDAR=true`
swaps in the fake.

Navigation is `Navigator.push`. Each screen owns a `ChangeNotifier`
controller. No global state, no packages for it.

`BookingController` loads access, calendars, and bookings, then builds one
slot grid per day of the shown week. `confirm` writes the calendar event
first and logs the booking second. If the write throws, nothing is logged
and the screen shows the snack bar. The event's title, location, and notes
come from the card; `end` is `date.at(endMinutes)`.

The calendar to write to is the stored one if it is still writable, else
the only writable one, else none (the picker opens).

## Tests

Unit tests for `core`, `data`, `suggestions`, and the adapter's mapping
functions. Widget and golden tests for everything visual, always against
the fakes. Goldens are 380 px wide at DPR 1 with Outfit loaded, generated
on Linux (`flutter test --update-goldens`), stored in `test/goldens/`.
Helpers live in `test/helpers/` (`golden.dart`, `fonts.dart`, `fakes.dart`).

## Decisions

| # | Decision |
| --- | --- |
| D1 | No state-management or router package. |
| D2 | JSON files via `path_provider`, atomic rename on write. |
| D3 | Local wall-clock everywhere; slot maths through `LocalDate.at`. |
| D4 | "Past bookings" means `start < now`; take the 3 most recent by start. |
| D5 | Weekday ties keep all; pad 30 min; clamp 06:00 to 22:00; small windows kept. |
| D6 | Precedence past, outside hours, conflict, highlighted, available. Appointments ending after 22:00 are blocked. |
| D7 | Conflicts from all calendars; all-day and free events never block; half-open overlap. |
| D8 | Only `createEvent` on the plugin. Never update or delete. |
| D9 | Stored calendar id used if still writable; a single writable calendar is used without asking. |
| D10 | Deleting a card deletes its local bookings and never touches the calendar. |
| D11 | Goldens at 380 px, DPR 1, Outfit, generated on Linux. |
| D12 | Hand-written English formatting, no `intl`. |
| D13 | Ids are 32 hex chars from `Random.secure()`. |
| D14 | Flutter pinned to 3.47.2 in CI. |
| D15 | Confirm writes the event, then logs the booking. A failed log after a successful write is accepted. |
| D16 | `USE_FAKE_CALENDAR` dart-define swaps in the fake. |
| D17 | Weeks are Monday to Sunday; cannot go before the current week. |
| D18 | Duration pills 30/45/60/90 plus Custom (5 to 480, step 5). Defaults 60, Mon to Fri, 08:00 to 18:00. |
