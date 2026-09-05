# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
