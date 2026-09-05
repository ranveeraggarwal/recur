# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## Unreleased

- Bookings whose calendar event has been deleted are dropped on the next
  Home or Booking load, so a card stops claiming it is booked and the
  suggestions stop counting the event that is no longer there.
- Booking: an event in the calendar now greys only the rows it actually
  covers. A row that is free but too close to the next event stays
  sand-white and reads `Not enough room`.
- Editor: a card can prefer more than one time of day. `Add a time` adds
  a window and each extra one has an × to remove it.
- Editor: `Copy from calendar` fills a new card in from an event already
  in the phone calendar - its name, duration, location, notes, weekdays,
  and the times of day it has run at. Events are picked from a week view
  of the real calendar, and a location or notes missing from the event
  you tap is taken from the most recent event of the same name that has
  them.

## 1.0.0 - 2026-09-05

- Home: a grid of event-type cards with an empty state and a button to add
  a card.
- Editor: a form to create, validate, and delete an event-type card.
- Booking: a week view of the calendar with a day strip, a slot timeline
  that blocks and highlights slots, and a confirm bar that writes the
  chosen slot to the calendar.
- Confirmation and calendar-picker sheets: a sheet that confirms a booking
  was made, and one to choose which calendar to write to when the phone
  has more than one.
- `DeviceCalendarGateway`: the adapter that reads calendars and busy times
  from, and writes events to, the phone's real calendar.
- Home: requests calendar access on load when it has not been asked for
  yet, so the system permission dialog appears without waiting for the
  user to open Booking.
