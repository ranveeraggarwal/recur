# Recur - product brief

Recur is an Android-only Flutter app for booking irregular recurring
appointments. Physio every few weeks, a trainer every ten days or so, a
haircut when it is due: things you rebook by hand at slightly different times
each cycle. Recur remembers what each appointment looks like, shows you a
week of your real calendar with the good slots highlighted, and writes the
one you pick into the phone calendar.

Package: `com.ranveeraggarwal.recur`. Android only (minSdk 24, targetSdk 35).

## What the app is

- A list of **event-type cards**. Each card describes one kind of appointment:
  name, duration, location, notes, preferred weekdays, and a preferred time
  window.
- Tapping a card opens a **week view** of the phone calendar. Slots that
  collide with existing calendar events are blocked. Slots that match the
  card's preference (or, once there is history, the pattern of recent
  bookings) are highlighted.
- Tapping a slot and confirming writes **one timed event** to the phone
  calendar and logs the booking locally so future suggestions get better.

That is the whole product. Everything below is detail.

## What the app is not

Strict scope. Do not build any of these, even as a stub:

- No accounts, sign-in, sync, or cloud of any kind. All data lives on the
  phone.
- No notifications or reminders of any kind.
- No editing or deleting of calendar events. Recur only ever creates events.
  If the user wants to move or cancel one, they do it in their calendar app.
- No recurring-event creation. Every booking is a single, one-off event.
- No machine learning. Suggestion logic is the fixed rule set in
  `docs/architecture.md`.
- No settings screen. The only setting is which calendar to write to, and it
  is a single picker that only appears when the phone has more than one
  writable calendar.
- No iOS, web, or desktop targets. The repo scaffold is Android-only and
  stays that way.
- No dark theme. One light theme, as specified in `docs/design-system.md`.

## Users and the moments that matter

One user: the phone's owner. They open Recur when they remember they need to
rebook something. The three moments that must feel effortless:

1. **Glance.** Open the app, see the cards, see at a glance when each was
   last booked.
2. **Pick.** Tap a card, land on the current week, spot the highlighted
   slots, tap one.
3. **Confirm.** Tap Confirm, see a short confirmation, be back at the cards.

Editing a card is rare and is allowed to feel like a form.

## Screens

There are exactly four screens plus one bottom-sheet picker.

### 1. Home

- App bar title: `Recur`.
- Body: a two-column grid of event-type cards. Column one and column two
  cards have mirrored asymmetric corner radii (see design system).
- Each card shows: name, a duration pill (for example `45 min`), location if
  set, and a "last booked" line: `Last booked 3 weeks ago`, `Last booked
  yesterday`, `Booked for Tue 8 Sep` (when the most recent booking is in the
  future), or `Not booked yet`.
- Tap a card: open Booking for that card.
- Long-press a card: open Editor for that card.
- Floating action button (bottom right): opens Editor for a new card.
- Empty state (no cards): the text `No events yet.` centred, with a smaller
  muted line `Tap + to add one.`
- If the phone has more than one writable calendar, the app bar shows a
  single calendar icon button that opens the calendar picker. Otherwise the
  app bar has no actions.

### 2. Editor

A form for one event type. Used for both new and existing cards.

- App bar title: `New event` or `Edit event`.
- Fields, in order:
  - Name (text, required, max 40 characters). Placeholder `PT session`.
  - Duration: a row of duration pills `30 min`, `45 min`, `60 min`, `90 min`
    plus a `Custom` pill that reveals a numeric field (5 to 480 minutes, in
    steps of 5). Default 60.
  - Location (text, optional, max 80 characters).
  - Notes (multi-line text, optional, max 500 characters). Written into the
    calendar event description.
  - Preferred weekdays: seven day pills `Mon` to `Sun`, multi-select. Default
    Mon to Fri.
  - Preferred time window: a start and an end time in 30-minute steps
    between 06:00 and 22:00. Default 08:00 to 18:00. End must be at least the
    duration after start.
- Primary button at the bottom: `Save`. Disabled until the form is valid.
- For an existing card only: a text button `Delete event type`, which asks
  `Delete "PT session"? Past bookings are removed from Recur. Calendar events
  are not touched.` with `Cancel` and `Delete`.
- Validation messages are short and specific: `Name is required.`,
  `End must be after start plus the duration.`

### 3. Booking

The week view for one card.

- App bar title: the card name. Subtitle line: duration and location, for
  example `60 min · Kungsholmen`.
- **Day strip** across the top: seven day pills for one Monday-to-Sunday
  week. Each pill shows the weekday abbreviation and the day number. Pills
  for days before today are disabled. A pill whose day has at least one
  highlighted, unblocked slot shows a small cedar dot. Chevrons on either
  side move one week back or forward; back is disabled when the displayed
  week is the current week. The header between the chevrons reads
  `Week of 7 Sep` (the Monday's date).
- **Timeline** below: a vertical list of 30-minute slots from 06:00 to
  22:00 (32 rows). Hour labels sit in a gutter on the left. Each row is a
  slot tile in one of these states: available, highlighted, blocked, or
  selected. Blocked slots show the calendar event title that blocks them
  when there is one (`Busy` if the event has no title), else `Past` or
  `Outside hours`.
- Tapping an available or highlighted slot selects it. Tapping it again
  clears the selection. Only one slot can be selected. Selecting a slot on
  another day clears the previous one.
- **Sticky confirm bar** pinned to the bottom: a summary line
  (`Tue 8 Sep, 10:00 to 11:00`, or `Pick a slot` when nothing is selected)
  and the `Confirm` button. The button is disabled with no selection.
- On first open the view shows the current week with today selected, and the
  timeline scrolled so the first highlighted slot of that day (or 08:00 if
  none) is near the top.
- **Calendar access states** replace the day strip and timeline when access
  is missing:
  - Not yet asked or asked but can ask again: text `Recur needs calendar
    access to show your week.` and a button `Allow calendar access`.
  - Permanently denied: text `Calendar access is off for Recur.` and a button
    `Open settings`.
  - No writable calendar on the phone: text `No writable calendar found.`
    and no button.
- When the user taps Confirm and more than one writable calendar exists but
  none has been chosen yet, the calendar picker opens first. Confirm then
  proceeds with the chosen calendar.
- On success: the Confirmation sheet appears (below), and when it dismisses
  the app returns to Home.
- On failure (the gateway throws): a snack bar `Couldn't add to calendar.`
  and the screen stays as it was, selection intact.

### 4. Confirmation

A bottom sheet, not a screen of its own.

- Content: a check icon in primary green, the line `Booked`, and the summary
  `Tue 8 Sep, 10:00 to 11:00` with the card name beneath in muted text.
- Auto-dismisses after two seconds. Tapping outside or dragging down also
  dismisses it.
- Dismissing (either way) pops the Booking screen and lands on Home.

### Calendar picker (bottom sheet)

- Title `Write bookings to`.
- One row per writable calendar: calendar name and, in muted text, the
  account name. The selected one shows a check mark in primary green.
- Tapping a row selects it, stores the choice, and closes the sheet.
- Only reachable from the Home app bar icon (when there are two or more
  writable calendars) and from the first Confirm when no calendar has been
  chosen.

## Slot suggestion rules

These are exact. See `docs/architecture.md` for the code shape.

1. A **slot** is a 30-minute wall-clock interval starting at 06:00, 06:30,
   ... 21:30 on a given day. Booking a slot creates an event from the slot
   start lasting the card's duration.
2. **Blocked** wins over everything. A slot is blocked when any of these
   hold:
   - Its start is not after the current time (it is in the past).
   - The interval `[start, start + duration)` overlaps a busy interval from
     the phone calendar (any calendar, not only the target one).
   - `start + duration` is after 22:00 on that day (the appointment would run
     outside hours).
3. **Highlighted** slots are computed from a **suggestion window**: a set of
   weekdays plus a start and end time of day.
   - If the card has fewer than 3 **past** bookings (bookings whose start is
     before now), the window is the card's stated preference: its preferred
     weekdays and preferred time window.
   - Otherwise, take the 3 most recent past bookings by start time. The
     weekdays are the most common weekday among the three; on a tie, every
     tied weekday is included. The time window is the earliest start time of
     day to the latest end time of day among the three, padded by 30 minutes
     on each side, then clamped to 06:00 to 22:00.
   - A slot is highlighted only if its day's weekday is in the window's
     weekdays and the whole appointment fits: `start >= windowStart` and
     `start + duration <= windowEnd`.
4. A slot that would be highlighted but is blocked is shown as blocked.
5. No machine learning, no weighting, no decay. Exactly the rules above.

## Conflict rules

- Busy intervals come from every calendar on the phone that the app can
  read, not only the one it writes to.
- Recurring events count via their expanded occurrences in the queried
  range.
- All-day events do not block slots. Events whose availability is `free`
  do not block slots.
- Overlap is half-open: an event ending at 10:00 does not block a slot
  starting at 10:00.

## Data kept on the phone

- Event types (the cards).
- Bookings: which card, start, end, the calendar and calendar event id it
  was written to, and when it was created. Bookings are never edited. They
  are removed only when their card is deleted.
- The chosen calendar id, if the user picked one.

## Copy rules

- Plain words. `PT session`, `Confirm`, `No events yet.`, `Booked`.
- Never the words "flow", "ritual", "breathe". Never all-caps.
- Sentences end with a full stop; button labels and titles do not.
- Times are 24-hour, `10:00`. Dates are `Tue 8 Sep`. Weeks are `Week of 7
  Sep`. Durations are `45 min`.

## Definition of done for v1

- All four screens and the picker work end to end against the in-memory
  fake calendar in widget tests.
- The real calendar adapter is wired in the app entry point and verified on
  a Pixel by the owner (see the "On-device verification" issue).
- `flutter analyze --fatal-infos`, `flutter test`, and `flutter build apk`
  pass in CI on every push.
