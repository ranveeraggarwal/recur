# Recur

Recur is an Android app for booking irregular recurring appointments, like
physio or a trainer, into your phone calendar. You keep a card for each kind
of appointment; when it is time to rebook, Recur shows you a week of your
real calendar with the good slots lit up, and writes one event when you
confirm. All data stays on the phone.

## What it is not

Recur has no accounts, sign-in, sync, or cloud of any kind. It has no
notifications or reminders. It never edits or deletes a calendar event, only
creates one, and every booking is a single, one-off event, never a
recurring series. There is no machine learning, just a fixed rule set for
suggesting slots. There is no settings screen beyond a calendar picker that
only appears when the phone has more than one writable calendar. The app is
Android only, with one light theme.

## Requirements

Flutter 3.47.2 stable (Dart 3.13.2). Android minSdk 24, targetSdk 35,
package `com.ranveeraggarwal.recur`.

## Run

Against the real device calendar:

```sh
flutter run
```

Against a fake, in-memory calendar, so it runs in an emulator without a
calendar account:

```sh
flutter run --dart-define=USE_FAKE_CALENDAR=true
```

## Test

```sh
TZ=Europe/Stockholm flutter test
```

Tests fix the timezone to Stockholm so date and daylight-saving logic is
exercised consistently, regardless of where they run.

## Goldens

Widget tests compare against golden images in `test/goldens/`. Regenerate
them on Linux, because CI compares on Linux:

```sh
TZ=Europe/Stockholm flutter test --update-goldens
```

Regenerate only the goldens your change actually affects, and name them in
the pull request.

## Release

Tagged pushes (`v*`) build a signed release APK and attach it to a GitHub
release. Signing needs a keystore, created once with `keytool`:

```sh
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Keep the keystore out of the repo (it's gitignored). Base64-encode it and add
these four repository secrets (Settings → Secrets and variables → Actions):

- `ANDROID_KEYSTORE_BASE64` - `base64 -w0 upload-keystore.jks`.
- `ANDROID_KEYSTORE_PASSWORD` - the keystore's password.
- `ANDROID_KEY_ALIAS` - the key alias (`upload` above).
- `ANDROID_KEY_PASSWORD` - the key's password.

To build locally without CI, write `android/key.properties` (also
gitignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

With no `key.properties` present, `flutter build apk --release` still works,
signed with the debug key.

To cut a release:

```sh
git tag v1.0.0 && git push --tags
```

## Docs

- `docs/product-brief.md` - what the app does and does not do.
- `docs/architecture.md` - layers, interfaces, data model, and the
  decisions made along the way.
- `docs/design-system.md` - the colour, size, and font tokens, and how
  each component uses them.
- `AGENTS.md` - toolchain, conventions, and traps hit while building this,
  for anyone (or anything) making changes.

## Licence

No licence file is included yet.
