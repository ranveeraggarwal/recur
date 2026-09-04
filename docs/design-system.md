# Recur - design system ("Wabi-Sabi Zen")

Quiet, warm, unhurried. Sand-coloured surfaces, one deep forest green for
everything you can act on, one cedar brown reserved for the few things that
deserve attention. Slightly asymmetric cards, no hard black or white, no
borders where a shadow will do. Nothing shouts.

Every value in this file is exact. Widgets read them from
`lib/theme/tokens.dart`; nothing in `lib/` may hard-code a colour, radius,
shadow, or font size that is not a token.

## Tokens

Written CSS-variable style so they can be read at a glance. The Dart names
in `lib/theme/tokens.dart` are given next to each.

```css
:root {
  /* Colour */
  --color-background: #F4EFE6;   /* RecurColors.background  - page background, sand */
  --color-surface:    #FAF7F2;   /* RecurColors.surface     - cards, sheets, fields, app bar */
  --color-text:       #1C1C19;   /* RecurColors.text        - primary text, near-black, never #000 */
  --color-muted:      #938F85;   /* RecurColors.muted       - secondary text, hour labels, hints, disabled text */
  --color-primary:    #2C4A3B;   /* RecurColors.primary     - forest green: buttons, FAB, selected states, links, check marks */
  --color-on-primary: #FAF7F2;   /* RecurColors.onPrimary   - text/icons on primary (same value as surface) */
  --color-accent:     #8A4B38;   /* RecurColors.accent      - cedar: highlighted slots and attention ONLY, never buttons */
  --color-accent-tint: rgba(138, 75, 56, 0.08);  /* RecurColors.accentTint - highlighted slot fill */
  --color-primary-tint: rgba(44, 74, 59, 0.08);  /* RecurColors.primaryTint - pressed state overlay on surfaces */
  --color-blocked:    #E9E3D8;   /* RecurColors.blocked     - blocked/past slot fill, disabled button fill */
  --color-divider:    #E3DDD2;   /* RecurColors.divider     - timeline hour lines, sheet handle */
  --color-error:      #9A4A3A;   /* RecurColors.error       - validation text (a slightly redder cedar) */

  /* Typography (family Outfit, vendored in assets/fonts) */
  --font-family: "Outfit";
  --text-display: 600 28px/34px;  /* RecurText.display - app bar titles on Home */
  --text-title:   600 20px/26px;  /* RecurText.title   - screen titles, card names, sheet titles */
  --text-body:    400 16px/22px;  /* RecurText.body    - body copy, field input, list rows */
  --text-label:   500 14px/18px;  /* RecurText.label   - pills, buttons, day pill labels, form labels */
  --text-caption: 400 12px/16px;  /* RecurText.caption - hour labels, "last booked", helper/error text */
  --text-button:  500 16px/20px;  /* RecurText.button  - ConfirmButton and Save */
  --letter-spacing: 0;            /* no tracking anywhere; no all-caps anywhere */

  /* Spacing (RecurSpacing.xs .. xxl) */
  --space-xs: 4px;  --space-sm: 8px;  --space-md: 12px;
  --space-lg: 16px; --space-xl: 24px; --space-xxl: 32px;

  /* Radii (RecurRadii) */
  --radius-card-col1: 16px 4px 16px 16px;   /* RecurRadii.cardColumnOne  (topLeft topRight bottomRight bottomLeft) */
  --radius-card-col2: 4px 16px 16px 16px;   /* RecurRadii.cardColumnTwo */
  --radius-button: 12px;                    /* RecurRadii.button */
  --radius-pill: 999px;                     /* RecurRadii.pill */
  --radius-field: 12px;                     /* RecurRadii.field */
  --radius-sheet: 20px 20px 0 0;            /* RecurRadii.sheet */
  --radius-slot: 8px;                       /* RecurRadii.slot */
  --radius-fab: 16px;                       /* RecurRadii.fab */

  /* Shadow (RecurShadows) */
  --shadow-card: 0 12px 24px -4px rgba(44, 74, 59, 0.08);  /* RecurShadows.card: offset (0,12), blur 24, spread -4, primary at 8% */
  --shadow-fab:  0 8px 16px -4px rgba(44, 74, 59, 0.16);   /* RecurShadows.fab */
  --shadow-sheet: 0 -8px 24px -4px rgba(44, 74, 59, 0.10); /* RecurShadows.sheet */

  /* Sizes (RecurSizes) */
  --size-touch-min: 44px;         /* minimum tappable height */
  --size-slot-row: 48px;          /* one 30-minute timeline row */
  --size-hour-gutter: 56px;       /* left gutter for hour labels */
  --size-day-pill: 44px x 64px;   /* width x height */
  --size-fab: 56px;
  --size-confirm-bar: 88px;       /* sticky bar total height incl. padding */
  --highlight-border: 3px;        /* SlotTile highlighted left border */
}
```

Flutter mapping notes:

- Shadow `0 12px 24px -4px rgba(44,74,59,0.08)` is
  `BoxShadow(color: Color(0x142C4A3B), offset: Offset(0, 12), blurRadius: 24, spreadRadius: -4)`.
  `0x14` is 8% of 255 rounded (20). The FAB shadow uses `0x29` (16%), the
  sheet `0x1A` (10%).
- `accentTint` is `Color(0x148A4B38)`. `primaryTint` is `Color(0x142C4A3B)`.
- Card radii are `BorderRadius.only(topLeft: 16, topRight: 4, bottomRight:
  16, bottomLeft: 16)` for column one and the mirror for column two.
- Fonts: `assets/fonts/Outfit-Regular.ttf` (400), `Outfit-Medium.ttf`
  (500), `Outfit-SemiBold.ttf` (600). Family name `Outfit`. Declared in
  `pubspec.yaml` under `flutter: fonts:`. The OFL licence file sits next to
  them.

### Theme rules

- `ThemeData` is built once in `lib/theme/app_theme.dart` from the tokens:
  `scaffoldBackgroundColor: background`, `colorScheme` with `primary`,
  `onPrimary`, `surface`, `onSurface: text`, `error`, `tertiary: accent`.
  `useMaterial3: true`.
- App bar: `surface` background, no elevation, no scroll-under tint
  (`scrolledUnderElevation: 0`, `surfaceTintColor: Colors.transparent`),
  title in `RecurText.title`, centred false.
- Material elevation is never used for cards; cards draw the token shadow
  themselves. `CardTheme` elevation 0.
- No `Colors.black`, `Colors.white`, `Colors.deepPurple`, or any Material
  default colour anywhere in `lib/`. Ripples use `primaryTint`.
- No text uses `TextStyle` literals outside `tokens.dart` except to change
  colour to another token.
- No borders on cards or pills. Text fields have a 1 px `divider` border
  that becomes 2 px `primary` when focused.

## Copy and tone

- Plain words: `PT session`, `Confirm`, `Save`, `Booked`, `No events yet.`
- Never "flow", "ritual", "breathe". No exclamation marks. No all-caps.
- Sentence case everywhere. Sentences end with a full stop; titles and
  button labels do not.

## Components

Each component lists its anatomy, every state, and the tokens it uses.
State names are the names used in the widget's constructor.

### EventCard (`lib/widgets/event_card.dart`)

Used in the Home grid. Two columns, 16 px gutter, 16 px page padding, so at
380 px each card is 166 px wide. Height wraps content, minimum 132 px.

Anatomy, top to bottom, 16 px inner padding:

1. Name in `RecurText.title`, `text`, max 2 lines, ellipsis.
2. 8 px gap, then a `DurationPill` (see below).
3. 8 px gap, location in `RecurText.caption`, `muted`, 1 line, ellipsis.
   Omitted (no gap) when null.
4. Flexible space, then the last-booked line in `RecurText.caption`,
   `muted`, 1 line. Text per `formatLastBooked` in the architecture doc.

Constructor: `EventCard({required EventType eventType, required Booking?
latestBooking, required DateTime now, required CardColumn column, required
VoidCallback onTap, required VoidCallback onLongPress})`.

| State | Look |
| --- | --- |
| default, column one | fill `surface`, radius `cardColumnOne`, shadow `card`, no border |
| default, column two | same, radius `cardColumnTwo` |
| pressed | `primaryTint` overlay clipped to the card radius (InkWell splash/highlight colours) |
| booked in future | last-booked line reads `Booked for Tue 8 Sep`; colour `primary` instead of `muted` |
| never booked | last-booked line `Not booked yet`, `muted` |

Goldens: `event_card_column_one`, `event_card_column_two`,
`event_card_never_booked`, `event_card_future_booking`,
`event_card_long_name` (a 2-line name with ellipsis, no location).

### DurationPill (`lib/widgets/duration_pill.dart`)

A small rounded label. Height 28 px, horizontal padding 12 px, radius
`pill`, text `RecurText.label`. Label text is `formatDuration(minutes)`
(`45 min`) or a provided label (`Custom`).

Constructor: `DurationPill({required String label, bool selected = false,
VoidCallback? onTap})`. Read-only when `onTap` is null (on EventCard).

| State | Fill | Text |
| --- | --- | --- |
| read-only (on card) | `primaryTint` | `primary` |
| unselected (Editor) | `surface`, 1 px `divider` border | `text` |
| selected (Editor) | `primary` | `onPrimary` |
| pressed | `primaryTint` overlay | unchanged |

No pill is ever `accent`.

Goldens: `duration_pill_states` (a row of read-only, unselected, selected).

### DayPill (`lib/widgets/day_pill.dart`)

One day in the Booking day strip. 44 x 64 px, radius `pill`, vertically
stacked: weekday abbreviation (`RecurText.caption`) over the day number
(`RecurText.label`). A 6 px dot 4 px under the number when
`hasSuggestions` is true.

Constructor: `DayPill({required LocalDate date, required bool selected,
required bool enabled, required bool hasSuggestions, required bool isToday,
VoidCallback? onTap})`.

| State | Fill | Text | Dot |
| --- | --- | --- | --- |
| default | transparent | `text` | `accent` when `hasSuggestions` |
| today (not selected) | transparent, 1 px `primary` border | `primary` | as default |
| selected | `primary` | `onPrimary` | `onPrimary` when `hasSuggestions` |
| disabled (past day) | transparent | `muted` | none, never |
| pressed | `primaryTint` overlay | unchanged | unchanged |

Selected wins over today. Disabled pills ignore taps.

Goldens: `day_pill_states` (a row: default, today, selected, disabled,
default with dot, selected with dot).

### SlotTile (`lib/widgets/slot_tile.dart`)

One 30-minute row in the timeline. Full width minus the 56 px hour gutter
and 16 px right padding. Height 48 px, with 2 px vertical inset so tiles do
not touch. Radius `slot`. Left content: the start time in
`RecurText.label`. Right content (blocked only): the reason text in
`RecurText.caption`, `muted`, 1 line, ellipsis.

Constructor: `SlotTile({required Slot slot, required bool selected,
VoidCallback? onTap})`. The tile derives its visual state from
`slot.state`, `slot.blockReason`, `slot.blockingTitle`, and `selected`.

| State | Fill | Left border | Text | Right text |
| --- | --- | --- | --- | --- |
| available | `surface` | none | `text` | none |
| highlighted | `accentTint` | 3 px `accent` (inside the radius, straight edge) | `text` | none |
| selected (from available or highlighted) | `primary` | none | `onPrimary` | none |
| blocked, conflict | `blocked` | none | `muted` | the event title, or `Busy` |
| blocked, past | `blocked` | none | `muted` | `Past` |
| blocked, outsideHours | `blocked` | none | `muted` | `Outside hours` |
| pressed (available/highlighted only) | `primaryTint` overlay | unchanged | unchanged | none |

Blocked tiles ignore taps and have no ripple. Selected always wins over
highlighted. The timeline draws a 1 px `divider` line at every full hour in
the gutter column and a hour label (`06:00`) in `RecurText.caption`,
`muted`, top-aligned to the row.

Goldens: `slot_tile_states` (a column: available, highlighted, selected,
conflict with title, conflict without title, past, outside hours).

### ConfirmButton (`lib/widgets/confirm_button.dart`)

The full-width primary button. Also used for `Save` in the Editor. Height
52 px, radius `button`, text `RecurText.button`. No icon. No elevation.

Constructor: `ConfirmButton({required String label, required VoidCallback?
onPressed, bool busy = false})`. `onPressed == null` means disabled.

| State | Fill | Text |
| --- | --- | --- |
| enabled | `primary` | `onPrimary` |
| pressed | `primary` with a `Color(0x1F1C1C19)` overlay (12% text) | `onPrimary` |
| disabled | `blocked` | `muted` |
| busy | `primary`, a 20 px `onPrimary` circular progress indicator replaces the label, taps ignored | none |

The Booking screen wraps it in the sticky confirm bar: `surface` fill,
shadow `sheet`, 16 px padding, summary line in `RecurText.caption`,
`muted` above the button (8 px gap), total height 88 px.

Goldens: `confirm_button_states` (a column: enabled, disabled, busy),
`confirm_bar` (the bar with a summary and enabled button).

### RecurTextField (`lib/widgets/recur_text_field.dart`)

Wraps `TextField`. Label above the field in `RecurText.label`, `muted`
(becomes `primary` when focused). Field fill `surface`, radius `field`,
1 px `divider` border, 14 px horizontal and 12 px vertical content
padding, input text `RecurText.body`, `text`. Placeholder in `muted`.
Helper or error text below in `RecurText.caption`.

Constructor: `RecurTextField({required String label, required
TextEditingController controller, String? placeholder, String? errorText,
String? helperText, int maxLines = 1, int? maxLength, TextInputType?
keyboardType, FocusNode? focusNode})`.

| State | Border | Label | Below |
| --- | --- | --- | --- |
| default | 1 px `divider` | `muted` | helper in `muted`, if any |
| focused | 2 px `primary` | `primary` | helper in `muted` |
| error | 2 px `error` | `error` | error text in `error` |
| disabled | 1 px `divider`, fill `blocked` | `muted` | none |
| multiline (notes) | as default, `maxLines: 4`, top-aligned text | | counter `120/500` in `caption` `muted`, right-aligned, when `maxLength` set |

Goldens: `text_field_states` (a column: default with placeholder, focused
with text, error, disabled, multiline with counter).

### RecurFab (`lib/widgets/recur_fab.dart`)

56 x 56 px, radius `fab` (a rounded square, not a circle), fill `primary`,
a 24 px `Icons.add` in `onPrimary`, shadow `fab`. No label. Positioned by
the Scaffold's default `FloatingActionButtonLocation.endFloat` with 16 px
margins.

Constructor: `RecurFab({required VoidCallback onPressed, String tooltip =
'Add event'})`.

| State | Fill | Shadow |
| --- | --- | --- |
| default | `primary` | `fab` |
| pressed | `primary` with `Color(0x1F1C1C19)` overlay | `fab` |

Goldens: `fab_default`.

### Sheets (ConfirmationSheet, CalendarPickerSheet)

Bottom sheets share: `surface` fill, radius `sheet`, shadow `sheet`, a
32 x 4 px `divider` drag handle centred 12 px from the top, 24 px inner
padding, and a bottom safe-area inset.

ConfirmationSheet: a 40 px `Icons.check_circle_outline` in `primary`, 12 px
gap, `Booked` in `RecurText.title`, 4 px gap, the slot summary in
`RecurText.body`, the card name in `RecurText.caption` `muted`. Total
height about 200 px. Auto-dismisses after 2 s.

CalendarPickerSheet: `Write bookings to` in `RecurText.title`, then one
56 px row per calendar: name in `RecurText.body`, account name in
`RecurText.caption` `muted` under it, and a 24 px `Icons.check` in
`primary` at the right of the selected row. Rows have `primaryTint`
ripple.

Goldens (M6): `confirmation_sheet`, `calendar_picker_sheet`.

## Screens at 380 px

Reference layout metrics so goldens are unambiguous.

- **Home**: app bar 56 px, title `Recur` in `RecurText.display`, 16 px page
  padding, 2-column grid with 16 px gutters, cards 166 px wide, FAB bottom
  right. Empty state: `No events yet.` in `RecurText.title` `text`,
  centred, with `Tap + to add one.` in `RecurText.body` `muted` 8 px below.
- **Editor**: app bar with back chevron and title; a scrolling column with
  24 px between field groups; the Save button pinned at the bottom in a
  88 px bar like the confirm bar.
- **Booking**: app bar with back chevron, title = card name, subtitle in
  `caption` `muted`; a 72 px week header row (chevrons 44 px, `Week of 7
  Sep` in `label` centred); the day strip (64 px pills, 8 px gaps, 16 px
  side padding, evenly spaced); a 1 px `divider`; the timeline scrolling
  underneath; the 88 px confirm bar pinned at the bottom.
- **Access states** on Booking: the text in `RecurText.body` `text` centred
  with 32 px horizontal padding, then a 16 px gap and a `ConfirmButton`
  sized to content (not full width) for the action.

## What "done" looks like for a UI issue

- The widget uses only tokens (grep `Color(` and `TextStyle(` in the widget
  file: nothing outside `tokens.dart`).
- Every state in the table has a golden at 380 px.
- Copy matches this document character for character.
- `flutter analyze --fatal-infos` is clean.
