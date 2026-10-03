# How Recur is built

A small app deserves a small architecture. Here is the whole thing.

## The tools

Flutter 3.47.2 (Dart 3.13.2), Android only, minSdk 24, targetSdk 35. One
plugin for reading the calendar, `device_calendar_plus` 0.8.0,
`path_provider` for a folder to save files in, and `http` for the address
lookup's calls to Nominatim. That is the full dependency list. Opening the
calendar app on a new event needs no package: a small method channel in
`MainActivity.kt` fires the intent.

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
  data/          the card model and where cards are saved
  calendar/      the gateway to the phone calendar, a fake, and the real one
  history/       reading bookings back out of the calendar
  places/        the gateway to Nominatim, a fake, and the real one
  suggestions/   the slot logic
  theme/         every colour, size, and font, in one file
  widgets/       cards, pills, buttons
  screens/       home, editor
```

Four ideas hold it together.

**One door to the calendar.** Everything that touches the phone calendar
goes through a small interface called `CalendarGateway`. It can check and
ask for permission, fetch busy times, list whole events (for the Editor's
`Copy from calendar` and for the history scan), and open the calendar app
on a new, filled-in event. It never writes, updates or deletes anything
itself. There is a fake version that lives in memory, and every screen
and every test uses the fake. Only one file in the whole app,
`device_calendar_gateway.dart`, knows the plugin and the method channel
exist.

**Places gateway.** The Location field's address suggestions go through the
same one-door rule, behind a small interface called `PlacesGateway`. Only
`lib/places/nominatim_places_gateway.dart` knows that Nominatim exists;
every screen and every test uses `FakePlacesGateway`. Nominatim is free and
needs no key, but its usage policy asks for a descriptive `User-Agent` and
at most one request a second, so the gateway itself sends a real
`User-Agent` naming the app and waits out any remainder of that second
before it sends the next request, rather than counting on the field's
typing debounce to keep the pace down. A failed lookup just returns no
suggestions; the field still works as a plain text field.

**Wall-clock time, always.** An appointment is "Tuesday at ten", not an
instant on a global timeline. So Recur stores and shows local times, and it
counts times of day in minutes since midnight (06:00 is 360, 22:00 is
1320). A tiny `LocalDate` type turns a date plus minutes into a `DateTime`.
Nothing adds hours to midnight to find a slot; on the day the clocks change
that would be an hour off. Tests that care run in the Stockholm zone.

**The calendar is the database.** The app keeps one file of its own: the
cards, as JSON in the app's folder, written to a temp name and renamed so a
crash cannot leave a half-written file. Tests swap in an in-memory store.
What you booked is not stored anywhere in Recur. Every event Recur opens
carries a marker in its notes, and the history is rebuilt from the
calendar on every launch and every return to the app.

## The data

A **card** (`EventType`) has a name, a duration in minutes, an optional
location and notes, the weekdays you prefer, and a non-empty list of
`TimeWindow`s: the times of day that suit you, any one of which is enough
for a slot to light up. Cards written before windows were a list are read
back from the old `preferredStartMinutes`/`preferredEndMinutes` pair, so
nothing on a phone needs migrating. A card also has a two-character
`code`, which names it inside the marker. A card saved before codes
existed gets one the first time it is loaded.

An **occurrence** is not stored. It is what the history scan builds from a
calendar event carrying a card's marker: the card code, the occurrence
code, the event's id, and its start and end as they are now in the
calendar.

## The marker

Every event Recur opens ends its notes with one line:

```
Booked with Recur - rcab3k7
```

`rc`, then the card code (`ab`), then the occurrence code (`3k7`). Both
codes use only `0-9` and `a-z`, so there are 1,296 card codes and 46,656
occurrence codes per card. The notes are the card's notes, a blank line,
then the marker; a card with no notes gets the marker alone.

- **Reading.** The scan looks for `Recur - rc` followed by exactly five of
  those characters, anywhere in the event's notes. Text the user adds above
  or below does not matter. An event whose marker line was deleted is not a
  booking.
- **Occurrence codes are random,** drawn fresh for every tap. Recur never
  looks one up. Its job is to collapse copies: a duplicated event, or every
  instance of an event the user made repeat, carries the same full code,
  and the scan keeps only the earliest event with a given code.
- **Card codes are never reused.** A deleted card's events stay in the
  calendar with its code, so a new card's code avoids every code on a card
  and every code the latest scan has seen. If the scan has not finished
  when a card is saved, it avoids what has been seen so far.

## The history scan

`lib/history/` rebuilds every card's occurrences from the calendar. It
runs on launch and whenever the app comes back to the foreground, which is
how an event saved in the calendar app shows up. Nothing is cached between
runs.

It reads in rings around today, each read only covering what the last one
did not:

1. today ± 7 days,
2. 7 to 30 days either side,
3. 30 to 365 days either side.

Each event is read once, so the whole scan costs one read of two years.
After each ring Home updates and the progress bar advances a third.

Because the rings move outwards, a card's answers settle early. The first
ring holding a past occurrence of a card holds its latest one, and the
first holding an upcoming occurrence holds its next one, so the card's
line is final as soon as both are found, or the scan ends. Its suggestion
window is final once three past occurrences are found. When every card
has settled, the scan stops without reading further rings.

The scan never throws. Without calendar access it reads nothing, every
card shows no line, and suggestions fall back to the card's own windows.

## The slot logic

Two pure functions, no side effects, easy to test.

`suggestionWindowFor` takes a card and its occurrences and returns a
suggestion: a set of weekdays plus a list of time spans. Fewer than three
past occurrences, it hands back the card's preference, every window of it.
Otherwise it takes the three most recent, picks the most common weekday
(ties keep all), spans the earliest start to the latest end, pads by 30
minutes, clamps to 06:00 to 22:00, and returns that one span in place of
the card's list.

`buildSlotGrid` takes a date, a duration, a suggestion, the busy times,
and "now", and returns the 32 slots of that day. Each slot is past,
outside hours, blocked by an overlap, highlighted, or available, checked
in exactly that order. The set of blocked slots is the same as it always
was — the appointment overlapping a busy interval — but a blocked slot
now says which kind it is. `conflict` means an event covers the row's own
30 minutes, and the row names it; `doesNotFit` means the row is free and
only the appointment's tail runs into a later event. So an hour in the
calendar greys the two rows it sits on, rather than every row an
hour-long appointment could clash with.

`firstSuggestedSlot` takes a card, its suggestion, the busy times, and
"now", and returns one start time. It runs `buildSlotGrid` for each day
from tomorrow through the next 14 days and returns the first
`highlighted` slot, since highlighted already means not past, inside
hours, clear of every busy interval, and inside the suggestion. If none of
those days has one, it returns tomorrow at the start of the card's first
preferred window, busy or not.

## The screens

Dependencies are bundled into one object and handed down the widget tree
with an `InheritedWidget` called `AppScope`. Screens navigate with plain
`Navigator.push`. Each screen has its own small controller (a
`ChangeNotifier`). No state-management library, no router library.

Tapping a card reads busy times for tomorrow through the next 14 days,
takes the card's suggestion from the history scan as it stands (finished
or not, so the tap never waits on it), picks the slot with
`firstSuggestedSlot`, and asks the gateway to open the calendar app.
The intent is `ACTION_INSERT` on `CalendarContract.Events.CONTENT_URI`
with the begin and end time, title, location, and description (notes plus
marker). Recur learns nothing back from it: the calendar app returns no
result and no event id. Whatever the user saved turns up in the next scan,
which starts when Recur comes back to the foreground. A phone with no app
that takes the intent is not supported; if launching it fails, Home shows
`Couldn't open your calendar.`

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
| Storage | One JSON file, the cards, atomic writes. Bookings live in the calendar, found by the marker. |
| Time | Local wall-clock. Minutes since midnight. `LocalDate.at`. |
| "Past bookings" | Occurrences whose start is before now. The three most recent count. |
| Window padding | 30 minutes each side, clamped to 06:00 to 22:00. Too-small windows are kept. |
| Slot precedence | Past, outside hours, overlap, highlighted, available. |
| Blocked kinds | An overlap is a `conflict` when an event covers the row's own 30 minutes (and the row names it), else `doesNotFit` (`Not enough room`, on the plain surface, still not tappable). |
| Conflicts | Every calendar. All-day and free events never block. Half-open overlap. |
| Plugin use | Read only. New events are opened in the calendar app with `ACTION_INSERT` and saved by the user there. |
| Places lookup | Nominatim: free, needs no API key, unlike Google Places or Mapbox. A convenience only - the Location field still works as plain text, and a failed or rate-limited lookup never blocks it. |
| Deleting a card | Removes the card. Its events stay in the calendar, and its code is never given to another card. |
| Marker | `Booked with Recur - rc` + 2-character card code + 3-character random occurrence code, `0-9a-z`, last line of the notes. Same full code on several events counts once, at the earliest. |
| History | Rebuilt from the calendar on launch and on every return to the foreground, in rings of ±7 days, ±30 days, ±365 days. Nothing cached. A card settles once its latest past, next upcoming and three past occurrences are found; the scan stops when every card has settled. |
| Suggested time | First highlighted slot from tomorrow through the next 14 days. None found: tomorrow at the start of the card's first window. Never today. |
| Without calendar access | Home shows the access message above the cards. Cards show no line, and the suggested time uses the card's windows with no busy times. |
| Changes made in the calendar app | Followed, not fought. The scan reads the event as it now is. |
| Existing bookings | Not migrated. Bookings made before the marker existed carry no code, so cards start with no history. |
| Preferred times | A non-empty list. Any window is enough for a slot to light up; each is validated on its own, and overlapping ones are allowed. |
| Prefilling a card | `Copy from calendar` shows the last 90 days and next 30 days of the calendar as a week view; tapping an event copies it. All-day, untitled, and events under 5 or over 480 minutes are not offered. |
| Where a prefilled detail comes from | The tapped occurrence supplies the name, duration, location and notes; every occurrence sharing the name supplies the weekdays and the window. A location or notes the tapped occurrence lacks is taken from the most recent occurrence that has one, treating `""` as missing since that is how Android stores a blank. |
| Goldens | 380 px, DPR 1, Outfit, generated on Linux. |
| Formatting | Hand-written English. No `intl`. |
| Ids | 32 hex characters from a secure random. |
| Editor defaults | 60 min, Mon to Fri, one window of 08:00 to 18:00. Custom duration 5 to 480 in steps of 5. |
| Outfit font | Google Fonts ships Outfit only as a variable font, so the three static weights are instanced from it at 400, 500 and 600 with fontTools and vendored under `assets/fonts`. |
| `formatLastBooked` signature | `Booking` does not exist yet, so it takes `{required DateTime? latestStart, required DateTime now}` instead of `(Booking? latest, DateTime now)`. |
| `formatSlotSummary` signature | `Slot` does not exist yet, so `core/formatting.dart` provides `formatDaySpan({required LocalDate date, required int startMinutes, required int endMinutes})` instead. |
| App icon | Adaptive icon: `ic_launcher_background` (primary green) behind a vector foreground of two off-square rounded rectangles in `surface`, echoing the home grid's cards. Legacy PNGs for pre-API-26 launchers are rasterized from the same shapes with Pillow, since no SVG rasterizer is available in the build container. |
| `FixedClock` mutation API | `Clock.now` is an interface method, and Dart does not allow a method and a property setter to share a name in the same class, so `FixedClock` exposes `setNow(DateTime value)` as a plain method rather than a `now` setter. |
| `EventType` trim contract | A `const` constructor can only assert potentially-constant expressions, and `String.trim()` is not one, so the constructor checks lengths only. Callers pass already-trimmed strings; `validateName` trims before checking. |
| Extra validator messages | The product brief names only `Name is required.` and `End must be after start plus the duration.` The remaining bounds needed messages too, so `EventType` adds plainly worded ones in the same sentence case. |
| `ThemeData.textTheme` equality | `ThemeData` merges the `TextTheme` passed to `buildRecurTheme()` onto the Material 3 default typography (adding a matching text decoration colour, for one), so `theme.textTheme.displaySmall` etc. is never `==` to the raw `RecurText.display` token. `app_theme_test.dart` asserts the individual properties (family, size, weight, height, letterSpacing, color) instead of object equality. |
| `RecurTextField` disabled state | The issue's constructor lists no `enabled` flag, so the disabled state (blocked fill, no helper/error text, ignores input) is driven by passing a `FocusNode(canRequestFocus: false)` via the existing `focusNode` parameter; `RecurTextField` treats `!focusNode.canRequestFocus` as disabled. |
| Golden helper for unbounded animations | `ConfirmButton`'s busy `CircularProgressIndicator` animates forever, so `tester.pumpAndSettle()` in `pumpGolden` times out. Added an optional `settle` parameter (default `true`); passing `settle: false` pumps a single fixed 300ms frame instead, landing the spinner partway through its arc for a stable, non-blank golden. |
| Golden file location vs. test file location | `test/widgets/*_test.dart` (per the issue) sit one directory below `test/app_golden_test.dart`, but `matchesGoldenFile('goldens/$name.png')` resolves relative to the calling test file's own directory, which would have scattered new PNGs under `test/widgets/goldens/`. `expectGolden` now resolves the golden path from `Directory.current` (the project root flutter test runs from) so every golden, regardless of its test file's location, lands in the single `test/goldens/` directory. |
| `MaterialIcons` font in goldens | `loadAppFonts` only registered the vendored Outfit faces, so `RecurFab`'s `Icons.add` rendered as the flutter_test fallback tofu box in `fab_default.png`. It now also loads `MaterialIcons-Regular.otf` via `rootBundle` (bundled automatically by `uses-material-design: true`) so icon goldens show the real glyph. |
| `buildSlotGrid` outside-hours boundary | The issue's own formula (`endMinutes > 1320 => outsideHours`) and its 90-minute prose example disagree: a 90-minute slot starting 20:30 ends exactly at 1320 (22:00), which is not `> 1320`, so by the formula it fits and is not blocked, but the prose lists it as blocked alongside 21:00 and 21:30. Kept the exact formula (strict `>`) since it is also required by the "all-day style interval passed in still blocks" test, where the last 30-minute slot (21:30, ending exactly at 1320) must be `conflict`, not `outsideHours`, for all 32 slots to share one reason. `slot_grid_test.dart`'s 90-minute test therefore blocks 21:00 and 21:30 only, leaving 20:00 and 20:30 unblocked by `outsideHours`. |
| `AppScope.updateShouldNotify` equality | `AppDependencies` is a plain `final class` with no `==` override (its fields are repositories and gateways, not value types), so `updateShouldNotify` compares `deps` by identity (`!=`). `main.dart` builds one `AppDependencies` for the app's lifetime, so this never actually triggers a rebuild in practice; the check exists so a future second `AppScope` with a genuinely different instance does notify. |
| `HomeScreen` reads `AppScope.of(context)` from `didChangeDependencies`, not `initState` | Flutter's own assertion forbids `dependOnInheritedWidgetOfExactType` (which `AppScope.of` calls) from completing inside `initState`: the dependency link isn't established until the widget's first build, so a value read in `initState` would silently go stale on the next `AppScope` change. `didChangeDependencies` is the framework-blessed place for this; `HomeScreen` caches the resolved `AppDependencies` in a field and guards the initial load with `_future ??= _load()` so it still runs exactly once. Later `EditorController`/`BookingController` construction should follow the same pattern despite the "constructed in `State.initState`" wording in this doc's App wiring section. |
| `HomeScreen` while its first load is pending | Neither the product brief nor the design system specifies a loading state for Home (the fake repositories and calendar resolve near-instantly). `HomeScreen` renders an empty `SizedBox.shrink()` body (app bar and FAB still show) until the first `FutureBuilder` snapshot has data, rather than a spinner, since no golden or copy exists for one. |
| Editor's weekday picker widget | Issue #21 leaves the choice open ("reuse `DurationPill` with the weekday label, or a compact `DayPill` variant"). `DayPill` bakes in a day number and a suggestions dot that Editor has no use for, so the Editor's "Preferred weekdays" row reuses `DurationPill` (`selected`/unselected exactly matches the toggle look Editor needs) with the weekday abbreviation as its label. |
| Editor's time-window picker widget | Issue #21 leaves the choice open ("two `DropdownMenu`s or a custom pill list"). Implemented as two `DropdownButtonFormField<int>`s (a private `_TimeField`) labelled "Start"/"End", styled with the same field decoration tokens as `RecurTextField` (`surface` fill, 1px `divider` border, `field` radius), listing every 30-minute mark from 06:00 to 22:00 via `formatMinutes`. |
| `DurationPill` stretching to full width inside a bare `Wrap` | `Wrap` measures each child with `BoxConstraints(maxWidth: <wrap's own available width>)`, not a truly unbounded constraint, and `DurationPill`'s inner `Container(alignment: Alignment.center, ...)` (via `Align`) fills any *finite* max width it's offered — so a bare `Wrap` of `DurationPill`s stretches every pill to one-per-row at full width (confirmed empirically: `Size(348.0, 28.0)` per pill vs. the expected ~69px). Every `Wrap` of `DurationPill`s in the Editor (duration presets + Custom, and the seven weekday pills) wraps each child in `IntrinsicWidth`, which measures its child at its own intrinsic width first and reports that fixed width to `Wrap`, restoring the compact chip layout `Row` gives for free. |
| Access-state `ConfirmButton` "sized to content" | Superseded (M8 must-fix #57): `ConfirmButton` gained an `expand` flag (default `true`, preserving every existing full-width caller); the access states (now on Home) pass `expand: false` so the button's own `SizedBox` drops its forced `width: double.infinity` and it sizes to the label's intrinsic width, replacing the earlier `SizedBox(width: 220)` approximation. |
| `ConfirmBar` height at 88px with and without a summary | `docs/design-system.md` gives one `--confirm-bar: 88px` for both Booking (always a real summary line, now removed) and the Editor's Save bar (`summary: ''`), but the button is a fixed 52px and the caption line is a fixed 16px, so no single padding constant fits both. `ConfirmBar` now computes its vertical padding as `(RecurSizes.confirmBar - contentHeight) / 2`, where `contentHeight` is 52 (no summary) or 52 + 16 + RecurSpacing.sm (with one) — landing on 18px padding for the Editor and 6px for Booking, both referencing `RecurSizes.confirmBar` directly so the two callers can't drift apart again. The summary `Text`/gap is omitted entirely (not just collapsed to a zero-height line) when `summary` is empty. |
| `editor_delete_dialog` golden name | Issue #58 suggests "`editor_delete_dialog.png` (or similar name)". Used that exact name, at the standard `goldenWidth` (380px) with a 400px height (enough to fit the `EditorScreen` behind the dialog plus the centred `AlertDialog`), alongside the existing functional delete-dialog test in `editor_screen_test.dart` rather than a new file. |
| `buildDependencies` location | The issue offers `lib/main.dart` or `lib/bootstrap.dart` for the extracted factory. Kept it in `lib/main.dart`, next to `main()`: the function is small, it is the only caller besides the new test, and a separate `bootstrap.dart` would just be one more file to keep in sync for no real gain in testability. |
| Release keystore path in `key.properties` | The issue names the four `key.properties` fields but not where the keystore file itself lives. `storeFile` is resolved with Gradle's `file()` from `android/app/build.gradle.kts`, so it is relative to `android/app` (matching the standard Flutter release-signing convention). CI writes the decoded keystore to `android/app/upload-keystore.jks` and `storeFile=upload-keystore.jks` in the properties it writes; a local `key.properties` can instead give an absolute path. |
| `EventType`'s `preferredWindows` vs. the old pair | `EventType` keeps `preferredStartMinutes`/`preferredEndMinutes` as getters over the first and last window, so the Editor and the tests that only care about one window read the same as before, but `toJson` writes only `preferredWindows` and `fromJson` falls back to the old pair when the new key is absent. |
| `TimeWindow`'s home | `lib/core/time_window.dart`, next to `LocalDate` and `time_of_day_minutes.dart`, rather than under `data/models/`: both the data layer (`EventType`) and the suggestion layer (`SuggestionWindow`) need it, and `core/` is the one place both already import. |
| Where the prefill logic lives | `prefillFor` is a pure function in `lib/screens/editor/event_prefill.dart`, so the fallbacks, rounding and clamping are unit-tested without a widget; `prefill_screen.dart` only reads the calendar and draws it. |
| A calendar, not a list, for the picker | Picking the right past appointment is a "which Tuesday was that" question, so the week and the time of day are what identifies it. The picker uses the week header and day pills over an hour grid of event blocks. It can go back, but only to the edges of the range it read, so a week on screen is always a week that was actually fetched. |
| The picker's hour range | 06:00-22:00, the hours a suggestion can fall in, stretched to cover any event of that day outside those hours. A booking cannot be made outside them, but an event copied *from* can sit anywhere, and a block off the grid would be unreachable. |
| Overlapping events in the picker | Each run of mutually overlapping events is split across as many columns as the run needs, every event in the run reporting the same column count so they line up. Without it a double-booked hour hides one of its events behind the other. |
| One calendar read for the picker | The whole 90-day-back, 30-day-ahead range is read once on open, and week navigation filters it in memory. It is the same set the sibling-occurrence lookup needs anyway, and it keeps the chevrons instant. |
| `Copy from calendar` on an existing card | Offered on a new card only. Prefilling replaces every field, which on an edit would quietly throw away what the user already has. |
| `WeekHeader` | The week header (chevrons around `Week of 7 Sep`) lives in `lib/widgets/week_header.dart`. With Booking gone, the copy-from-calendar picker is its only user. A null callback greys its chevron, which is how the picker stops at the range it read. |
