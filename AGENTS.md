# Working on Recur

Recur is an Android-only Flutter app for booking irregular recurring
appointments (physio, trainer) into the phone calendar.

Read these before touching code. They are the source of truth; issues quote
them, but the docs win if they disagree.

- `docs/product-brief.md` - what the app does and does not do.
- `docs/architecture.md` - layers, interfaces, data model, decisions.
- `docs/design-system.md` - tokens and per-component specs.

Toolchain: Flutter 3.47.2 stable (Dart 3.13.2). CI pins this version.

Validation commands (all must pass before you push):

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
TZ=Europe/Stockholm flutter test
flutter build apk --debug
```

Golden tests: `TZ=Europe/Stockholm flutter test --update-goldens` regenerates
`test/goldens/*.png`. Generate goldens on Linux; CI compares on Linux.

Rules that apply to every change:

- Nothing touches the real calendar plugin except `lib/calendar/device_calendar_gateway.dart`.
  Every screen and every test uses `FakeCalendarGateway`.
- No new dependencies unless the issue you are working on names them.
- No accounts, cloud, notifications, or editing/deleting calendar events.
- Copy is plain. Never the words "flow", "ritual", "breathe". No all-caps.
