# Releasing

Releases are tag-driven. Pushing a tag that starts with `v` runs
`.github/workflows/release.yml`, which checks formatting, analyzes, runs the
tests, builds a signed release APK, and publishes it as a GitHub release with
generated notes. The version name comes from the tag (`v1.2.0` gives
`1.2.0`) and the build number from the workflow run number, so the version in
`pubspec.yaml` does not matter for release builds.

## One-time setup

Install a JDK (any will do; CI uses Temurin 17), then create the keystore.
Keep it outside the repo, one file per app:

```sh
mkdir -p ~/keystores
keytool -genkeypair -v \
  -keystore ~/keystores/recur-release.jks \
  -alias recur \
  -keyalg RSA -keysize 2048 -validity 10000
```

Back up the file and both passwords. If they are lost, updates can no longer
be installed over an existing copy of the app.

Add four repository secrets (Settings → Secrets and variables → Actions):

- `ANDROID_KEYSTORE_BASE64` - `base64 -w0 recur-release.jks` on Linux, or
  `base64 -i recur-release.jks | tr -d '\n'` on macOS.
- `ANDROID_KEYSTORE_PASSWORD` - the keystore password.
- `ANDROID_KEY_ALIAS` - `recur`.
- `ANDROID_KEY_PASSWORD` - the key password.

## Cutting a release

1. Check that CI is green on `main`.
2. Tag and push:

   ```sh
   git checkout main && git pull
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. Watch the Release run in the Actions tab. When it finishes, the signed
   APK is attached to the release page.
4. Install the APK over the previous version to confirm the update works.

If the run fails, fix it on `main`, delete the tag
(`git push origin :refs/tags/v1.0.0` and `git tag -d v1.0.0`), and tag again.
If the release was already published, use a new patch version instead.

## Building locally

Write `android/key.properties` (gitignored):

```properties
storeFile=/absolute/path/to/recur-release.jks
storePassword=...
keyAlias=recur
keyPassword=...
```

Then `flutter build apk --release`. With no `key.properties`, the build is
signed with the debug key.
