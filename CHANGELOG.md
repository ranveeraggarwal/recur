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
- Editor: the Location field suggests addresses as you type, looked up
  from OpenStreetMap. This is the app's only network use; a failed lookup
  just means no suggestions, and the field still works as plain text.
- Home and Booking no longer go blank when calendar access has not been
  granted. Booking shows its `Allow calendar access` state instead, and
  `Copy from calendar` now has the same button rather than a dead end.
- A card, a booking log, or a settings file that cannot be read now says
  so. Home offers `Couldn't read your cards.`; Booking and the Editor
  keep their app bar so there is a way back.
- Home keeps the cards on screen while it reloads, grows its cards with
  the system font size, and reloads when Recur returns from the
  background, so a calendar event deleted elsewhere is noticed.
- Booking: a slot whose start time has passed while the screen sat open
  can no longer be confirmed, and the day strip moves on over midnight.
  The timeline scrolls to each day's own first good slot when you switch
  days, and the strip fits a 320 px screen.
- Booking: opening a card that has since been deleted closes the screen
  instead of showing an empty one, and the Editor no longer offers to
  edit a card that is gone.
- Booking: a failed calendar write and a failed booking log now read
  differently. If the event reached your calendar and only Recur's own
  record failed, it says so rather than inviting a second booking.
- Editor: the Minutes field follows the duration pills, the delete dialog
  names the card as it was saved, and a save or delete that fails says so
  instead of doing nothing.
- Slot tiles, day pills and cards now carry labels for screen readers,
  including that a card is booked by tapping and edited by holding.
- The address lookup identifies itself to OpenStreetMap properly and
  sends at most one request a second, and release builds have the
  network permission it needs.
- Data files are flushed before the rename that makes them live, so a
  crash cannot leave a half-written file. A card file with bad weekdays
  or an empty location is reported as bad rather than crashing.
- A calendar event with no length no longer blocks slots or breaks the
  week view.

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
