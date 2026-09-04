# How Recur is built

A small app deserves a small architecture. Here is the whole thing.

## The tools

Flutter 3.47.2 (Dart 3.13.2), Android only, minSdk 24, targetSdk 35. One
plugin for the calendar, `device_calendar_plus` 0.8.0, and `path_provider`
for a folder to save files in. That is the full dependency list.

Before you push anything:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
TZ=Europe/Stockholm flutter test
flutter build apk --debug
```

## The shape

```
lib/
  core/          dates, clocks, ids, and the little text formatters
  data/          the three models and where they are saved
  calendar/      the gateway to the phone calendar, a fake, and the real one
  suggestions/   the slot logic
  theme/         every colour, size, and font, in one file
  widgets/       cards, pills, tiles, buttons
  screens/       home, editor, booking
```

Three ideas hold it together.

**One door to the calendar.** Everything that touches the phone calendar
goes through a small interface called `CalendarGateway`. It can check and
ask for permission, list calendars you can write to, fetch busy times, and
create one event. There is a fake version that lives in memory, and every
screen and every test uses the fake. Only one file in the whole app,
`device_calendar_gateway.dart`, knows the plugin exists.

**Wall-clock time, always.** An appointment is "Tuesday at ten", not an
instant on a global timeline. So Recur stores and shows local times, and it
counts times of day in minutes since midnight (06:00 is 360, 22:00 is
1320). A tiny `LocalDate` type turns a date plus minutes into a `DateTime`.
Nothing adds hours to midnight to find a slot; on the day the clocks change
that would be an hour off. Tests that care run in the Stockholm zone.

**Files, not a database.** The app has three things to remember: the cards,
the bookings, and which calendar you chose. Each is a small JSON file in
the app's folder, written to a temp name and renamed so a crash cannot leave
a half-written file. Three repositories read and write them, one per thing.
Tests swap in an in-memory store.

## The data

A **card** (`EventType`) has a name, a duration in minutes, an optional
location and notes, the weekdays you prefer, and a start and end time.

A **booking** has the card it belongs to, a start and end, and the id of
the calendar and event it was written to. Bookings are never edited; they
disappear only when their card is deleted.

**Settings** is one optional string: the chosen calendar id.

## The slot logic

Two pure functions, no side effects, easy to test.

`suggestionWindowFor` takes a card and its bookings and returns a window:
a set of weekdays plus a start and end time. Fewer than three past
bookings, it hands back the card's preference. Otherwise it takes the three
most recent, picks the most common weekday (ties keep all), spans the
earliest start to the latest end, pads by 30 minutes, and clamps to 06:00
to 22:00.

`buildSlotGrid` takes a date, a duration, a window, the busy times, and
"now", and returns the 32 slots of that day. Each slot is past, outside
hours, a conflict, highlighted, or available, checked in exactly that
order.

## The screens

Dependencies are bundled into one object and handed down the widget tree
with an `InheritedWidget` called `AppScope`. Screens navigate with plain
`Navigator.push`. Each screen has its own small controller (a
`ChangeNotifier`). No state-management library, no router library.

When you confirm, the Booking controller writes the calendar event first
and logs the booking second. If the write fails, nothing is logged and you
see `Couldn't add to calendar.` The calendar it writes to is the one you
chose, or the only writable one, or it asks.

Run the app against the fake calendar with
`flutter run --dart-define=USE_FAKE_CALENDAR=true`.

## Tests

Unit tests for the logic, widget tests for the screens, and golden images
for every visual state, taken at 380 px wide with the Outfit font loaded.
Goldens are generated on Linux, which is what CI runs. Nothing in the test
suite touches the real plugin.

Load the fonts from `setUpAll`, never from inside a `testWidgets` body. A
widget test runs in a fake-async zone where a real file read never
completes, so loading them in the test body hangs until it times out.

## Decisions we made so nobody has to make them again

| | |
| --- | --- |
| State and routing | Plain Flutter. No packages. |
| Storage | JSON files, one per thing, atomic writes. |
| Time | Local wall-clock. Minutes since midnight. `LocalDate.at`. |
| "Past bookings" | Start is before now. The three most recent count. |
| Window padding | 30 minutes each side, clamped to 06:00 to 22:00. Too-small windows are kept. |
| Slot precedence | Past, outside hours, conflict, highlighted, available. |
| Conflicts | Every calendar. All-day and free events never block. Half-open overlap. |
| Plugin use | Create events only. Never update or delete. |
| Calendar choice | Stored id if still writable, else the only writable one, else ask. |
| Deleting a card | Removes its bookings in Recur. The calendar is untouched. |
| Goldens | 380 px, DPR 1, Outfit, generated on Linux. |
| Formatting | Hand-written English. No `intl`. |
| Ids | 32 hex characters from a secure random. |
| Confirm order | Calendar event first, booking log second. |
| Weeks | Monday to Sunday. You cannot go back before this week. |
| Editor defaults | 60 min, Mon to Fri, 08:00 to 18:00. Custom duration 5 to 480 in steps of 5. |
| Outfit font | Google Fonts ships Outfit only as a variable font, so the three static weights are instanced from it at 400, 500 and 600 with fontTools and vendored under `assets/fonts`. |
| `formatLastBooked` signature | `Booking` does not exist yet, so it takes `{required DateTime? latestStart, required DateTime now}` instead of `(Booking? latest, DateTime now)`. |
| `formatSlotSummary` signature | `Slot` does not exist yet, so `core/formatting.dart` provides `formatDaySpan({required LocalDate date, required int startMinutes, required int endMinutes})` instead. |
| `FixedClock` mutation API | `Clock.now` is an interface method, and Dart does not allow a method and a property setter to share a name in the same class, so `FixedClock` exposes `setNow(DateTime value)` as a plain method rather than a `now` setter. |
| `EventType` trim contract | A `const` constructor can only assert potentially-constant expressions, and `String.trim()` is not one, so the constructor checks lengths only. Callers pass already-trimmed strings; `validateName` trims before checking. |
| Extra validator messages | The product brief names only `Name is required.` and `End must be after start plus the duration.` The remaining bounds needed messages too, so `EventType` adds plainly worded ones in the same sentence case. |
| `FakeCalendarGateway.createEvent` validation messages | The issue says it "mirrors the real plugin" for the `end`-after-`start` and non-empty-`title` checks but does not name the `ArgumentError` text, so it uses `ArgumentError.value` with plainly worded, sentence-case messages ("Must be after start.", "Must not be empty."). |
| `ThemeData.textTheme` equality | `ThemeData` merges the `TextTheme` passed to `buildRecurTheme()` onto the Material 3 default typography (adding a matching text decoration colour, for one), so `theme.textTheme.displaySmall` etc. is never `==` to the raw `RecurText.display` token. `app_theme_test.dart` asserts the individual properties (family, size, weight, height, letterSpacing, color) instead of object equality. |
| `RecurTextField` disabled state | The issue's constructor lists no `enabled` flag, so the disabled state (blocked fill, no helper/error text, ignores input) is driven by passing a `FocusNode(canRequestFocus: false)` via the existing `focusNode` parameter; `RecurTextField` treats `!focusNode.canRequestFocus` as disabled. |
| Golden helper for unbounded animations | `ConfirmButton`'s busy `CircularProgressIndicator` animates forever, so `tester.pumpAndSettle()` in `pumpGolden` times out. Added an optional `settle` parameter (default `true`); passing `settle: false` pumps a single fixed 300ms frame instead, landing the spinner partway through its arc for a stable, non-blank golden. |
| Golden file location vs. test file location | `test/widgets/*_test.dart` (per the issue) sit one directory below `test/app_golden_test.dart`, but `matchesGoldenFile('goldens/$name.png')` resolves relative to the calling test file's own directory, which would have scattered new PNGs under `test/widgets/goldens/`. `expectGolden` now resolves the golden path from `Directory.current` (the project root flutter test runs from) so every golden, regardless of its test file's location, lands in the single `test/goldens/` directory. |
| `MaterialIcons` font in goldens | `loadAppFonts` only registered the vendored Outfit faces, so `RecurFab`'s `Icons.add` rendered as the flutter_test fallback tofu box in `fab_default.png`. It now also loads `MaterialIcons-Regular.otf` via `rootBundle` (bundled automatically by `uses-material-design: true`) so icon goldens show the real glyph. |
