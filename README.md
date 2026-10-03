# Recur

Recur is an Android app for booking irregular recurring appointments, like
physio or a trainer, into your phone calendar. You keep a card for each kind
of appointment; when it is time to rebook, Recur shows you a week of your
real calendar with the good slots lit up, and writes one event when you
confirm. All data stays on the phone.

## Run

Requires Flutter 3.47.2 stable.

```sh
flutter run
```

To run in an emulator without a calendar account, use the fake calendar:

```sh
flutter run --dart-define=USE_FAKE_CALENDAR=true
```

## Test

```sh
TZ=Europe/Stockholm flutter test
```

## Docs

- `docs/product-brief.md` - what the app does and does not do.
- `docs/architecture.md` - layers, interfaces, data model, decisions.
- `docs/design-system.md` - colour, size and font tokens.
- `docs/release.md` - how to cut a release.
- `AGENTS.md` - toolchain, conventions, and known traps.
