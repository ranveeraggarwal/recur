# Recur

Some appointments never land on a fixed schedule. Physio every three weeks
or so. The trainer when your legs have recovered. A haircut when it starts
to look like a haircut is due. Each time you rebook, you open the calendar
app, scroll around, and try to remember what worked last time.

Recur remembers for you.

## The idea in one breath

You make a card for each appointment. When it is time to rebook, you tap
the card and your calendar app opens a new event with everything filled
in: the name, how long it takes, where it is, your notes, and a time that
suits you and is free. Change anything you like there, then save it. Next
time, the suggested time is a little smarter.

Recur does two things: it fills in the details, and it suggests a slot.
Your calendar app does the rest, and your calendar is where Recur keeps
its history. That is the whole app. Android only. Everything stays on the
phone. The only thing that ever leaves it is the text you type into a
location field, which is sent to OpenStreetMap to suggest an address, and
you can ignore the suggestions.

## What it will never do

No accounts, no sync, no cloud storage. No notifications. It never writes,
edits or deletes anything in your calendar itself; your calendar app does
the saving, and only when you tap save there. No machine learning, no
settings screen, no dark mode. If a feature is not on this page, it is not
in the app.

## The screens

**Home** is a grid of cards, two across, with a plus button in the corner.
A card shows the name, how long it takes, where it is, and a line like
`Last booked 3 weeks ago` or `Booked for Tue 8 Sep`. Tap to book, hold to
edit. An empty Home says `No events yet.` and, quietly, `Tap + to add one.`

Each time Recur opens, and each time you come back to it, it reads your
calendar again to find what you have booked. A thin bar under the app bar
shows it working, and each card's line appears as soon as Recur has found
its answer. The bar goes away when it is done.

If Recur cannot see the calendar yet, a short message sits above the cards
with one button: `Allow calendar access`, or `Open settings` if the phone
has locked it out. The cards still work, but they show no line and the
suggested time is only a guess.

**Editor** is a plain form: name, duration (`30 min`, `45 min`, `60 min`,
`90 min`, or `Custom`), location, notes, which weekdays suit you, and the
times of day that suit you, between 06:00 and 22:00. One time is enough,
but `Add a time` gives you another, so a card can want mornings and late
afternoons and nothing in between; each extra one has an × to take it
away again. Defaults are 60 minutes, Monday to Friday, 08:00 to 18:00.
Save stays grey until the form makes sense. Delete warns you:
`Delete "PT session"? Events already in your calendar stay there.`

A new card starts with `Copy from calendar`. It opens a week of your real
calendar - day pills and an hour grid - and you can go back as far as
three months, because copying looks backwards. Tap a day, tap the event
you mean, and the card fills in: its name, how long it takes, where it is,
its notes, the weekdays it falls on, and the times of day it runs at.
Where it is and its notes come from the event you tapped, or from the most
recent one with the same name that has them, so a series whose latest
entry lost its address still brings the address. Everything it fills in,
you can change.

## How you book

Tap a card. Recur picks a time and opens your calendar app on a new event
with the card's name, length, location and notes, and that time. The notes
end with a line like `Booked with Recur - rcab3k7`. That line is how Recur
finds the event again later, so leave it in. Pick a different time there,
use your calendar app's own way of finding a time, choose which calendar
it goes in, or back out without saving; Recur does not mind.

## How it picks the time

Two simple rules, no cleverness.

A card's **window** is the days and times that suit it. Until you have
booked a card three times, the windows are the ones you typed into the
Editor, and any one of them is enough. After that, Recur looks at your
last three bookings: the weekday you use most (ties keep both), and the
earliest start to the latest finish, with half an hour of slack on each
side.

The **suggested time** is the first half hour, starting tomorrow and
looking up to two weeks ahead, where the whole appointment fits inside the
window, finishes by 22:00, and overlaps nothing in any of your calendars.
All-day events and events marked "free" do not get in the way. An event
that ends at 10:00 does not block a slot that starts at 10:00. If nothing
fits in those two weeks, Recur suggests tomorrow at the start of the
card's first window, and you sort it out in your calendar app.

## Your calendar is the history

Recur does not keep a list of what you booked. It reads it back from your
calendar: any event whose notes carry a card's line counts as a booking of
that card, wherever and whenever you saved it. Move it, and Recur follows.
Delete it, or delete the line, and it no longer counts. Copies of one
event, or every repeat of an event you made repeat, count once, at the
earliest one.

Deleting a card leaves its events in your calendar. A new card never picks
up an old card's events.

## How it talks

Short words. `PT session`, `Save`, `Booked for Tue 8 Sep`. Times look like `10:00`,
dates like `Tue 8 Sep`, durations like `45 min`. It never says "flow",
"ritual", or "breathe", and it never shouts in capitals.
