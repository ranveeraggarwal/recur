# How Recur looks

Think of a quiet room with a wooden table. Sand-coloured surfaces, one deep
forest green for anything you can press, and one warm cedar brown saved for
the few things that deserve your attention. Cards sit a little off-square,
like they were placed by hand. Nothing has a hard border and nothing
shouts.

## The palette and the numbers

Every value below lives in `lib/theme/tokens.dart`. Nowhere else in the app
is a colour, size, or font written out by hand.

```css
:root {
  --background: #F4EFE6;      /* the page, warm sand */
  --surface:    #FAF7F2;      /* cards, sheets, fields, the app bar */
  --text:       #1C1C19;      /* nearly black, never black */
  --muted:      #938F85;      /* second-rank text, hints, disabled */
  --primary:    #2C4A3B;      /* forest green: buttons, selected things */
  --on-primary: #FAF7F2;
  --accent:     #8A4B38;      /* cedar: highlighted slots and the day dot. Never a button. */
  --accent-tint:  rgba(138, 75, 56, 0.08);
  --primary-tint: rgba(44, 74, 59, 0.08);   /* ripples and pressed states */
  --blocked:    #E9E3D8;      /* greyed slots, disabled buttons */
  --divider:    #E3DDD2;
  --error:      #9A4A3A;

  --font: "Outfit";           /* bundled in assets/fonts, weights 400 500 600 */
  --display: 600 28px/34px;   --title: 600 20px/26px;   --body: 400 16px/22px;
  --label:   500 14px/18px;   --caption: 400 12px/16px; --button: 500 16px/20px;

  --space: 4 8 12 16 24 32;

  --radius-card-left:  16px 4px 16px 16px;  /* cards in the left column */
  --radius-card-right: 4px 16px 16px 16px;  /* cards in the right column */
  --radius-button: 12px;  --radius-pill: 999px;  --radius-slot: 8px;
  --radius-fab: 16px;     --radius-sheet: 20px 20px 0 0;

  --shadow-card:  0 12px 24px -4px rgba(44, 74, 59, 0.08);
  --shadow-fab:   0 8px 16px -4px rgba(44, 74, 59, 0.16);
  --shadow-sheet: 0 -8px 24px -4px rgba(44, 74, 59, 0.10);

  --slot-row: 48px;  --hour-gutter: 56px;  --day-pill: 44px x 64px;
  --fab: 56px;       --confirm-bar: 88px;  --highlight-edge: 3px;
}
```

House rules: no pure black or white, no Material purple, no elevation
(cards draw their own soft shadow), no borders on cards or pills, no
capitals, no letter spacing. Ripples are the green tint.

## The pieces

**Card.** Sand-white, off-square corners that mirror left and right, a soft
green shadow. Name on top, a small duration pill, the location, and the
"last booked" line at the bottom in muted grey (green if the booking is
still ahead of you). Pressing tints it green.

**Duration pill.** A small rounded label like `45 min`. On a card it is a
quiet green tint. In the Editor it is outlined until you pick it, then
solid green.

**Day pill.** A tall rounded pill with the weekday over the day number.
Today wears a thin green ring. The chosen day is solid green. Past days go
grey and stop responding. A small cedar dot underneath means "there are good
slots here".

**Slot tile.** One row of the timeline, 48 px tall. Available is plain
sand-white. Highlighted has an 8% cedar wash and a 3 px cedar edge on the
left. Selected is solid green with light text. Blocked is flat `blocked`
grey with a muted reason on the right: the event's name, `Busy`, `Past`, or
`Outside hours`. Blocked tiles do not react to touch.

**Confirm button.** Full width, 52 px, green, rounded 12 px. Disabled is
`blocked` grey with muted text. While working it shows a small spinner
instead of the label. It lives in an 88 px bar with a one-line summary
above it. The Editor's Save button is the same component.

**Text field.** Label above, sand-white box with a hairline `divider`
border that turns into a 2 px green line when focused, or a 2 px `error`
line when something is wrong. Notes get four lines and a `120/500`
counter.

**Plus button.** A 56 px rounded square, not a circle, in green with a
light plus sign and the fab shadow.

**Sheets.** Sand-white, 20 px top corners, a small grey handle, 24 px
padding. The confirmation sheet is a green check, `Booked`, the slot, and
the card name. The calendar picker is `Write bookings to` and one 56 px row
per calendar, with a green check on the chosen one.

## Screens at 380 px

Home: a 56 px app bar with `Recur` in display size, 16 px margins, cards
166 px wide, plus button bottom right. Editor: 24 px between groups, Save
pinned at the bottom. Booking: a 72 px week header (`Week of 7 Sep` with
44 px chevrons), the day strip, a hairline, the timeline, the confirm bar.
Access messages sit centred in body text with a content-sized button below.

## Words

Short and plain, sentence case. `PT session`, `Confirm`, `Save`, `Booked`,
`No events yet.` Never "flow", "ritual", or "breathe". No capitals, no
exclamation marks.

## When a screen is done

It uses only the tokens above, every state has a golden image at 380 px,
the words match this page exactly, and `flutter analyze --fatal-infos`
has nothing to say.
