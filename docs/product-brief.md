# Recur

Some appointments never land on a fixed schedule. Physio every three weeks
or so. The trainer when your legs have recovered. A haircut when it starts
to look like a haircut is due. Each time you rebook, you open the calendar
app, scroll around, and try to remember what worked last time.

Recur remembers for you.

## The idea in one breath

You make a card for each appointment. When it is time to rebook, you tap
the card, see a week of your real calendar with the good slots lit up, tap
one, tap Confirm. Recur writes the event to your phone calendar and notes
that you booked it. Next time, the suggestions are a little smarter.

That is the whole app. Android only. Everything stays on the phone.

## What it will never do

No accounts. No cloud. No notifications. It never edits or deletes anything
in your calendar, it only adds. No recurring events, no machine learning,
no settings screen, no dark mode. If a feature is not on this page, it is
not in the app.

## The four screens

**Home** is a grid of cards, two across, with a plus button in the corner.
A card shows the name, how long it takes, where it is, and a line like
`Last booked 3 weeks ago` or `Booked for Tue 8 Sep`. Tap to book, hold to
edit. An empty Home says `No events yet.` and, quietly, `Tap + to add one.`

**Editor** is a plain form: name, duration (`30 min`, `45 min`, `60 min`,
`90 min`, or `Custom`), location, notes, which weekdays suit you, and the
times of day that suit you, between 06:00 and 22:00. One time is enough,
but `Add a time` gives you another, so a card can want mornings and late
afternoons and nothing in between; each extra one has an × to take it
away again. Defaults are 60 minutes, Monday to Friday, 08:00 to 18:00.
Save stays grey until the form makes sense. Delete warns you:
`Delete "PT session"? Past bookings are removed from Recur. Calendar
events are not touched.`

A new card starts with `Copy from calendar`. It opens a sheet of the
events already in your calendar, one row per name, newest first, and
filling in the name, how long it takes, where it is, the notes, the
weekdays it has fallen on, and the times of day it has run at. Everything
it fills in, you can change.

**Booking** is the week view. Seven day pills across the top, a timeline of
30-minute slots down the page from 06:00 to 22:00, and a Confirm bar
stuck to the bottom. Busy slots are greyed out and tell you why: the event
name, `Busy`, `Past`, or `Outside hours`. An hour in your calendar greys
the two rows it actually covers, no more. A row that is free itself but
too close to the next event stays sand-white, says `Not enough room`, and
does not respond. Good slots have a warm cedar edge. Tap one and the bar
reads `Tue 8 Sep, 10:00 to 11:00`.

If Recur cannot see the calendar yet, the timeline gives way to a short
message and one button: `Allow calendar access`, or `Open settings` if the
phone has locked it out. If there is no calendar it can write to, it says
so and offers nothing else.

**Confirmation** is a small sheet that slides up, says `Booked`, shows the
slot, and slides away two seconds later, leaving you on Home.

There is one extra sheet, `Write bookings to`, that lists your calendars.
You only ever see it if the phone has more than one calendar Recur could
write to.

## How it picks the good slots

Two simple rules, no cleverness.

A slot is **blocked** if it is already in the past, if the appointment
would overlap anything in any of your calendars, or if it would run past
22:00. Blocked always wins. A blocked slot names the event when the event
covers that half hour, and reads `Not enough room` when the clash is only
because the appointment would run on into it.

A slot is **highlighted** if it sits inside a window. Until you have
booked a card three times, the windows are the ones you typed into the
Editor, and any one of them is enough.
After that, Recur looks at your last three bookings: the weekday you use
most (ties keep both), and the earliest start to the latest finish, with
half an hour of slack on each side. The whole appointment has to fit inside
the window to light up.

All-day events and events marked "free" do not block. An event that ends at
10:00 does not block a slot that starts at 10:00.

Your calendar is yours, and you can delete an event Recur wrote. When
Recur next opens, a booking whose event has gone is quietly forgotten:
the card stops saying it is booked, and the suggestions stop counting it.
If Recur cannot read the calendar at that moment it changes nothing and
tries again next time.

## How it talks

Short words. `PT session`, `Confirm`, `Booked`. Times look like `10:00`,
dates like `Tue 8 Sep`, durations like `45 min`. It never says "flow",
"ritual", or "breathe", and it never shouts in capitals.
