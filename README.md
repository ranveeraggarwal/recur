# Recur

Recur is an Android app for booking irregular recurring appointments into your phone calendar.

Built with Flutter 3.47.2 stable.

## Running

Against the real device calendar:

```sh
flutter run
```

Against the fake calendar, so it runs in an emulator without a calendar
account:

```sh
flutter run --dart-define=USE_FAKE_CALENDAR=true
```

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

See `AGENTS.md` and the `docs/` folder for contributor information.
