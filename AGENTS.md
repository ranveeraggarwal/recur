# Working on Recur

Recur is an Android-only Flutter app for booking irregular recurring
appointments (physio, trainer) into the phone calendar.

Read these before touching code. They are the source of truth; issues quote
them, but the docs win if they disagree.

- `docs/product-brief.md` - what the app does and does not do.
- `docs/architecture.md` - layers, interfaces, data model, decisions.
- `docs/design-system.md` - tokens and per-component specs.

Toolchain: Flutter 3.47.2 stable (Dart 3.13.2). CI pins this version.

## Before you push

CI runs these in order and stops at the first failure, so one formatting slip
hides every other result.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
TZ=Europe/Stockholm flutter test
flutter build apk --debug
```

Run `dart format lib test` and commit whatever it changes. Do not try to
write format-clean Dart by hand. The Dart 3.7+ formatter rewrites more than
long lines: it collapses a split constructor call back onto one line when it
fits, and wraps a signature that does not. This is the most common way a
change arrives red.

## If Flutter is missing

A fresh container may not have it. Install the pinned version:

```sh
curl -sSL -o /tmp/flutter.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz
tar -xJf /tmp/flutter.tar.xz -C /opt
export PATH=/opt/flutter/bin:$PATH
```

That gives you format, analyze and test. It does not give you an Android SDK,
so `flutter build apk` stays CI's job. If you cannot run a check, say so in
the pull request instead of implying it passed.

## Traps we have already hit

- **Load fonts from `setUpAll`, never inside `testWidgets`.** A widget test
  body runs in a fake-async zone, so the real file read inside `loadAppFonts`
  never completes. The test then hangs until it times out ten minutes later
  rather than failing fast. Every golden test depends on getting this right.
- **The Outfit weights are generated, not downloaded.** Google Fonts ships
  Outfit only as a variable font whose default weight is Thin, so a plain
  download would render the app in hairline text. The three static faces in
  `assets/fonts` were instanced from it with fontTools. Do not swap them for
  a fresh download.
- **`.claude/worktrees/` is agent scratch space.** It is ignored, and it must
  never be committed. Clear stale ones with `git worktree remove --force`.

## Golden tests

`TZ=Europe/Stockholm flutter test --update-goldens` regenerates
`test/goldens/*.png`. Generate them on Linux, because CI compares on Linux.
Regenerate only the goldens your change actually affects, and name them in
the pull request.

## Working with GitHub from a container

- Changes under `.github/workflows/` need the `workflow` OAuth scope. If a
  push is rejected for that reason, leave the file outside that directory and
  ask a human to move it.
- If the GitHub MCP tools are unavailable or their token has expired, the
  REST API still works for issues and pull requests.

## Rules that apply to every change

- Nothing touches the real calendar plugin except
  `lib/calendar/device_calendar_gateway.dart`. Every screen and every test
  uses `FakeCalendarGateway`.
- No new dependencies unless the issue you are working on names them.
- No accounts, cloud, notifications, or editing/deleting calendar events.
- Copy is plain. Never the words "flow", "ritual", "breathe". No all-caps.
