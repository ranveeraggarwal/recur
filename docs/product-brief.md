# Recur

Recur is an Android app for booking appointments you rebook every few weeks
at slightly different times: physio, a trainer, a haircut. You describe each
appointment once. When it is time to rebook, Recur shows a week of your
calendar, highlights the good slots, and writes the one you pick into your
phone calendar.

Package `com.ranveeraggarwal.recur`. Android only, minSdk 24, targetSdk 35.

## What it does

- You keep a list of **cards**. A card is one kind of appointment: name,
  duration, location, notes, preferred weekdays, preferred time window.
- Tap a card and you get a **week view**. Slots that clash with your calendar
  are blocked. Slots that fit your preference, or your recent pattern, are
  highlighted.
- Tap a slot, tap Confirm, and Recur writes **one calendar event** and
  remembers the booking.

## What it does not do

No accounts, no cloud, no notifications. It never edits or deletes calendar
events. No recurring events. No machine learning. No settings screen except
one calendar picker. No iOS, web, or dark theme.

## Screens

**Home.** A two-column grid of cards and a plus button. Each card shows the
name, a duration pill (`45 min`), the location, and a line like
`Last booked 3 weeks ago`, `Booked for Tue 8 Sep`, or `Not booked yet`.
Tap a card to book. Long-press to edit. With nothing added the screen says
`No events yet.` and under it `Tap + to add one.` If the phone has two or
more writable calendars, a calendar icon in the app bar opens the picker.

**Editor.** A form: name, duration pills (`30 min`, `45 min`, `60 min`,
`90 min`, `Custom`), location, notes, weekday pills, and a start and end
time in 30-minute steps between 06:00 and 22:00. Defaults: 60 min, Mon to
Fri, 08:00 to 18:00. `Save` is disabled until the form is valid. Errors:
`Name is required.` and `End must be after start plus the duration.`
Existing cards get `Delete event type`, which asks
`Delete "PT session"? Past bookings are removed from Recur. Calendar events
are not touched.`

**Booking.** The card name in the app bar. A week header (`Week of 7 Sep`)
with back and forward chevrons. A strip of seven day pills, past days
disabled, a small dot on days that have suggestions. Below it a timeline of
30-minute slots from 06:00 to 22:00. Blocked slots say why: the event's
title, `Busy`, `Past`, or `Outside hours`. Tap a slot to select it. A bar
at the bottom shows `Pick a slot` or `Tue 8 Sep, 10:00 to 11:00` and the
`Confirm` button.

If calendar access is missing the timeline is replaced by one of:

- `Recur needs calendar access to show your week.` with `Allow calendar access`
- `Calendar access is off for Recur.` with `Open settings`
- `No writable calendar found.` with no button

If there are two or more writable calendars and none is chosen, Confirm
opens the picker first. If the write fails: snack bar
`Couldn't add to calendar.`

**Confirmation.** A bottom sheet: a green check, `Booked`, the slot
summary, the card name. It closes by itself after two seconds and you land
on Home.

**Calendar picker.** A bottom sheet titled `Write bookings to` with one row
per writable calendar. Tap to choose.

## How slots are chosen

A slot is a 30-minute start time. Booking it creates an event of the card's
duration.

**Blocked** (always wins):

- the slot start is not after now
- the appointment would overlap any event in any calendar
- the appointment would end after 22:00

**Highlighted** comes from a window (weekdays plus a start and end time):

- Fewer than 3 past bookings: the window is the card's preference.
- Otherwise take the last 3 past bookings. Weekdays: the most common one
  (ties keep all). Time: earliest start to latest end, padded 30 minutes each
  side, clamped to 06:00 to 22:00.
- A slot is highlighted only if the whole appointment fits inside the
  window.

Conflicts come from every calendar, with recurring events expanded. All-day
events and events marked free do not block. An event ending at 10:00 does
not block a slot starting at 10:00.

## Copy

Plain words. `PT session`, `Confirm`, `Booked`, `No events yet.` Never
"flow", "ritual", or "breathe". Never all-caps. Times `10:00`, dates
`Tue 8 Sep`, durations `45 min`.
