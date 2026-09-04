# Design system

Quiet and warm. Sand surfaces, one forest green for anything you can tap,
one cedar brown for the few things that deserve attention. Slightly
asymmetric cards, soft shadows, no borders, nothing shouting.

Every value here lives in `lib/theme/tokens.dart`. Nothing else in `lib/`
hard-codes a colour, radius, shadow, or text style.

## Tokens

```css
:root {
  --color-background: #F4EFE6;   /* page */
  --color-surface:    #FAF7F2;   /* cards, sheets, fields, app bar */
  --color-text:       #1C1C19;
  --color-muted:      #938F85;   /* secondary text, hints, disabled */
  --color-primary:    #2C4A3B;   /* forest green: buttons, FAB, selected states */
  --color-on-primary: #FAF7F2;
  --color-accent:     #8A4B38;   /* cedar: highlighted slots and the day dot only, never buttons */
  --color-accent-tint:  rgba(138, 75, 56, 0.08);   /* Color(0x148A4B38) */
  --color-primary-tint: rgba(44, 74, 59, 0.08);    /* Color(0x142C4A3B), ripples and pressed */
  --color-blocked:    #E9E3D8;   /* blocked slots, disabled buttons */
  --color-divider:    #E3DDD2;
  --color-error:      #9A4A3A;

  --font-family: "Outfit";       /* assets/fonts, weights 400 500 600 */
  --text-display: 600 28px/34px;
  --text-title:   600 20px/26px;
  --text-body:    400 16px/22px;
  --text-label:   500 14px/18px;
  --text-caption: 400 12px/16px;
  --text-button:  500 16px/20px;

  --space: 4 8 12 16 24 32;      /* xs sm md lg xl xxl */

  --radius-card-col1: 16px 4px 16px 16px;   /* top-left top-right bottom-right bottom-left */
  --radius-card-col2: 4px 16px 16px 16px;
  --radius-button: 12px;  --radius-field: 12px;  --radius-pill: 999px;
  --radius-slot: 8px;     --radius-fab: 16px;    --radius-sheet: 20px 20px 0 0;

  --shadow-card:  0 12px 24px -4px rgba(44, 74, 59, 0.08);
  --shadow-fab:   0 8px 16px -4px rgba(44, 74, 59, 0.16);
  --shadow-sheet: 0 -8px 24px -4px rgba(44, 74, 59, 0.10);

  --size-touch-min: 44px;  --size-slot-row: 48px;  --size-hour-gutter: 56px;
  --size-day-pill: 44px x 64px;  --size-fab: 56px;  --size-confirm-bar: 88px;
  --highlight-border: 3px;
}
```

Rules: no pure black or white, no Material purple, no elevation (cards draw
their own shadow), no borders on cards or pills, no all-caps, no letter
spacing. App bar is `surface` with no elevation or scroll tint. Ripples use
`primary-tint`.

## Components

**EventCard.** `surface` fill, column-one or column-two radii, card shadow,
16 px padding, 166 px wide in the grid. Name in `title` (2 lines max), a
read-only `DurationPill`, location in `caption` `muted`, last-booked line
in `caption` `muted` (or `primary` when the booking is in the future).
Takes plain values: `name`, `durationMinutes`, `location`,
`lastBookedText`, `lastBookedIsFuture`, `column`, `onTap`, `onLongPress`.

| State | Look |
| --- | --- |
| default | as above |
| pressed | `primary-tint` overlay |

**DurationPill.** 28 px tall, 12 px side padding, `pill` radius, `label`
text.

| State | Fill | Text |
| --- | --- | --- |
| read-only (on a card) | `primary-tint` | `primary` |
| unselected | `surface`, 1 px `divider` border | `text` |
| selected | `primary` | `on-primary` |

**DayPill.** 44 x 64, `pill` radius. Weekday in `caption` over the day
number in `label`, a 6 px dot below when the day has suggestions. Takes
`weekdayLabel`, `dayNumber`, `selected`, `enabled`, `hasSuggestions`,
`isToday`, `onTap`.

| State | Fill | Text | Dot |
| --- | --- | --- | --- |
| default | none | `text` | `accent` |
| today | none, 1 px `primary` ring | `primary` | `accent` |
| selected | `primary` | `on-primary` | `on-primary` |
| disabled (past) | none | `muted` | never |

**SlotTile.** One 48 px row (44 px painted), `slot` radius. Start time in
`label` on the left; a reason in `caption` `muted` on the right when
blocked. Takes `timeLabel`, `appearance`, `reasonText`, `onTap`.

| Appearance | Fill | Extra |
| --- | --- | --- |
| available | `surface` | |
| highlighted | `accent-tint` | 3 px `accent` left edge |
| selected | `primary` | text `on-primary` |
| blocked | `blocked` | text `muted`; reason is the event title, `Busy`, `Past`, or `Outside hours`; no tap |

The timeline keeps a 56 px gutter with hour labels in `caption` `muted`
and a 1 px `divider` line at each full hour.

**ConfirmButton.** Full width, 52 px, `button` radius, `button` text. Used
for `Confirm` and `Save`.

| State | Fill | Text |
| --- | --- | --- |
| enabled | `primary` | `on-primary` |
| pressed | `primary` + 12% `text` overlay | `on-primary` |
| disabled | `blocked` | `muted` |
| busy | `primary` | 20 px spinner instead of the label |

The confirm bar around it: `surface`, sheet shadow, 16 px padding, a
summary line in `caption` `muted`, 88 px tall.

**RecurTextField.** Label above in `label`. Field `surface` fill, `field`
radius, 1 px `divider` border, 14/12 px padding, `body` text, placeholder
`muted`, helper or error in `caption` below.

| State | Border | Label |
| --- | --- | --- |
| default | 1 px `divider` | `muted` |
| focused | 2 px `primary` | `primary` |
| error | 2 px `error` | `error` |
| disabled | 1 px `divider`, `blocked` fill | `muted` |

Multiline (notes) is 4 lines with a `120/500` counter.

**RecurFab.** 56 px rounded square (`fab` radius), `primary`, a 24 px plus
in `on-primary`, fab shadow. Pressed adds a 12% `text` overlay.

**Sheets.** `surface`, `sheet` radius and shadow, a 32 x 4 `divider` handle,
24 px padding. Confirmation: 40 px check in `primary`, `Booked` in `title`,
summary in `body`, card name in `caption` `muted`; closes after 2 s.
Picker: `Write bookings to` in `title`, 56 px rows with name in `body` and
account in `caption` `muted`, a `primary` check on the chosen row.

## Screens at 380 px

- Home: 56 px app bar, `Recur` in `display`, 16 px padding and gutters,
  cards 166 px wide, FAB bottom right. Empty state `No events yet.` in
  `title` with `Tap + to add one.` in `body` `muted` below.
- Editor: 24 px between groups, Save in an 88 px bar at the bottom.
- Booking: 72 px week header (`Week of 7 Sep` in `label`, 44 px chevrons),
  day strip of 64 px pills, a divider, the timeline, the 88 px confirm bar.
- Access states: the message in `body` centred with 32 px side padding,
  then a content-sized `ConfirmButton`.

## Copy

Plain words, sentence case. `PT session`, `Confirm`, `Save`, `Booked`,
`No events yet.` Never "flow", "ritual", "breathe". No all-caps, no
exclamation marks.

## Done means

Only tokens used, a golden at 380 px for every state above, copy matching
this file exactly, and `flutter analyze --fatal-infos` clean.
