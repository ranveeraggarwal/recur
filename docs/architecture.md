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
| `buildSlotGrid` outside-hours boundary | The issue's own formula (`endMinutes > 1320 => outsideHours`) and its 90-minute prose example disagree: a 90-minute slot starting 20:30 ends exactly at 1320 (22:00), which is not `> 1320`, so by the formula it fits and is not blocked, but the prose lists it as blocked alongside 21:00 and 21:30. Kept the exact formula (strict `>`) since it is also required by the "all-day style interval passed in still blocks" test, where the last 30-minute slot (21:30, ending exactly at 1320) must be `conflict`, not `outsideHours`, for all 32 slots to share one reason. `slot_grid_test.dart`'s 90-minute test therefore blocks 21:00 and 21:30 only, leaving 20:00 and 20:30 unblocked by `outsideHours`. |
| `AppScope.updateShouldNotify` equality | `AppDependencies` is a plain `final class` with no `==` override (its fields are repositories and gateways, not value types), so `updateShouldNotify` compares `deps` by identity (`!=`). `main.dart` builds one `AppDependencies` for the app's lifetime, so this never actually triggers a rebuild in practice; the check exists so a future second `AppScope` with a genuinely different instance does notify. |
| `HomeScreen` reads `AppScope.of(context)` from `didChangeDependencies`, not `initState` | Flutter's own assertion forbids `dependOnInheritedWidgetOfExactType` (which `AppScope.of` calls) from completing inside `initState`: the dependency link isn't established until the widget's first build, so a value read in `initState` would silently go stale on the next `AppScope` change. `didChangeDependencies` is the framework-blessed place for this; `HomeScreen` caches the resolved `AppDependencies` in a field and guards the initial load with `_future ??= _load()` so it still runs exactly once. Later `EditorController`/`BookingController` construction should follow the same pattern despite the "constructed in `State.initState`" wording in this doc's App wiring section. |
| `HomeScreen` while its first load is pending | Neither the product brief nor the design system specifies a loading state for Home (the fake repositories and calendar resolve near-instantly). `HomeScreen` renders an empty `SizedBox.shrink()` body (app bar and FAB still show) until the first `FutureBuilder` snapshot has data, rather than a spinner, since no golden or copy exists for one. |
| Editor's weekday picker widget | Issue #21 leaves the choice open ("reuse `DurationPill` with the weekday label, or a compact `DayPill` variant"). `DayPill` bakes in a day number and a suggestions dot that Editor has no use for, so the Editor's "Preferred weekdays" row reuses `DurationPill` (`selected`/unselected exactly matches the toggle look Editor needs) with the weekday abbreviation as its label. |
| Editor's time-window picker widget | Issue #21 leaves the choice open ("two `DropdownMenu`s or a custom pill list"). Implemented as two `DropdownButtonFormField<int>`s (a private `_TimeField`) labelled "Start"/"End", styled with the same field decoration tokens as `RecurTextField` (`surface` fill, 1px `divider` border, `field` radius), listing every 30-minute mark from 06:00 to 22:00 via `formatMinutes`. |
| `DurationPill` stretching to full width inside a bare `Wrap` | `Wrap` measures each child with `BoxConstraints(maxWidth: <wrap's own available width>)`, not a truly unbounded constraint, and `DurationPill`'s inner `Container(alignment: Alignment.center, ...)` (via `Align`) fills any *finite* max width it's offered — so a bare `Wrap` of `DurationPill`s stretches every pill to one-per-row at full width (confirmed empirically: `Size(348.0, 28.0)` per pill vs. the expected ~69px). Every `Wrap` of `DurationPill`s in the Editor (duration presets + Custom, and the seven weekday pills) wraps each child in `IntrinsicWidth`, which measures its child at its own intrinsic width first and reports that fixed width to `Wrap`, restoring the compact chip layout `Row` gives for free. |
| `BookingController.showWeek` and the current-week floor | The excerpted `BookingController` API has no method to reject a `showWeek` call for a week before the current one — the product brief's "back is disabled when the displayed week is the current week" is phrased as a chevron (UI) state, not a controller invariant. `showWeek` therefore navigates to whatever `LocalDate` it's given; `BookingScreen` is the one that disables the back chevron's `onPressed` when `weekMonday == today.mondayOfWeek`, so a user can never trigger it, but a test calling `showWeek` directly with an earlier Monday would not be rejected. |
| Selected date/slot when `showWeek` moves outside the current selection | Neither doc says what happens to `selectedDate`/`selectedSlot` when navigating to a week that doesn't contain them. `showWeek` resets `selectedDate` to the new `weekMonday` (so some day is always selected) and clears `selectedSlot` (matching the acceptance criterion that selection survives a week change only when the selected date stays in the displayed week). |
| Booking app bar subtitle | `AppBar` has no built-in subtitle slot. The title is a two-line `Column` (`Text(name, style: title)` then `Text('$duration · $location', style: caption/muted)`), matching the product brief's "title = card name, subtitle in caption muted" without the location segment (and its `·` separator) when the card has no location. |
| Booking's initial `Timeline` scroll offset | The product brief says the timeline "scrolled so the first highlighted slot of that day (or 08:00 if none) is near the top." Implemented as `ScrollController(initialScrollOffset: index * RecurSizes.slotRow)`, where `index` is the first `SlotState.highlighted` slot's position in the 32-slot grid, or the 08:00 slot's position (index 4) if none, or 0 as a final fallback. |
| Access-state `ConfirmButton` "sized to content" | Superseded (M8 must-fix #57): `ConfirmButton` gained an `expand` flag (default `true`, preserving every existing full-width caller); the Booking access states pass `expand: false` so the button's own `SizedBox` drops its forced `width: double.infinity` and it sizes to the label's intrinsic width, replacing the earlier `SizedBox(width: 220)` approximation. |
| `ConfirmBar` height at 88px with and without a summary | `docs/design-system.md` gives one `--confirm-bar: 88px` for both Booking (always a real summary line) and the Editor's Save bar (`summary: ''`), but the button is a fixed 52px and the caption line is a fixed 16px, so no single padding constant fits both. `ConfirmBar` now computes its vertical padding as `(RecurSizes.confirmBar - contentHeight) / 2`, where `contentHeight` is 52 (no summary) or 52 + 16 + RecurSpacing.sm (with one) — landing on 18px padding for the Editor and 6px for Booking, both referencing `RecurSizes.confirmBar` directly so the two callers can't drift apart again. The summary `Text`/gap is omitted entirely (not just collapsed to a zero-height line) when `summary` is empty. |
| `editor_delete_dialog` golden name | Issue #58 suggests "`editor_delete_dialog.png` (or similar name)". Used that exact name, at the standard `goldenWidth` (380px) with a 400px height (enough to fit the `EditorScreen` behind the dialog plus the centred `AlertDialog`), alongside the existing functional delete-dialog test in `editor_screen_test.dart` rather than a new file. |
| `ConfirmationSheet`/`CalendarPickerSheet` drag handle | `showModalBottomSheet`'s built-in `showDragHandle` draws a handle in the sheet's own default styling, not `RecurColors.divider`/32×4px, and the design excerpt says to "draw the 32 x 4 px `divider` handle yourself." Both sheets pass `showDragHandle: false` (the default) and draw a private `_DragHandle`/inline `Container` (32×4, `divider`, radius 2, centred, 12px-ish from the top via the sheet's own top padding) as the first child instead. |
| Confirmation sheet auto-dismiss timer | `showModalBottomSheet`'s `builder` doesn't get a `dispose` hook, so the 2-second auto-dismiss is a bare `Timer` started in `builder` that checks `Navigator.of(sheetContext).canPop()` before popping (guarding against the sheet already having been dismissed by a tap-outside or drag, which cancels nothing but the guard makes the resulting `pop()` a no-op instead of an error). |
| Booking Confirm error handling | The product brief specifies the failure snack bar and "the screen stays as it was, selection intact," but not what happens to a partial failure inside `confirm()` itself. Per the architecture doc's confirm-ordering contract, `BookingController.confirm` always clears `isConfirming` in a `finally` block before rethrowing, and never clears `selectedSlot` on failure — only a successful confirm (via the screen popping to Home) ends the flow. |
| `DeviceCalendarGateway.createEvent` wrapped-exception message | The issue's mapping table says to "wrap `DeviceCalendarException` and `PlatformException` in `CalendarWriteException`" but not what message to surface. `DeviceCalendarException` already carries a human-readable `message`, so that's passed straight through with the original exception as `cause`. `PlatformException` has no non-nullable message, so a plain fallback ("Failed to create calendar event.") is used when `e.message` is null, again with the original exception as `cause`. |
| `buildDependencies` location | The issue offers `lib/main.dart` or `lib/bootstrap.dart` for the extracted factory. Kept it in `lib/main.dart`, next to `main()`: the function is small, it is the only caller besides the new test, and a separate `bootstrap.dart` would just be one more file to keep in sync for no real gain in testability. |
| Release keystore path in `key.properties` | The issue names the four `key.properties` fields but not where the keystore file itself lives. `storeFile` is resolved with Gradle's `file()` from `android/app/build.gradle.kts`, so it is relative to `android/app` (matching the standard Flutter release-signing convention). CI writes the decoded keystore to `android/app/upload-keystore.jks` and `storeFile=upload-keystore.jks` in the properties it writes; a local `key.properties` can instead give an absolute path. |
