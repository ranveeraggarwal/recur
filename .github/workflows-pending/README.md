# Pending workflow

`release.yml` here is the finished release workflow. It could not be pushed
to `.github/workflows/` from the planning session because the credentials
used there lack GitHub's `workflow` scope. Move it into place from a machine
with normal push rights:

```sh
git mv .github/workflows-pending/release.yml .github/workflows/release.yml
git rm .github/workflows-pending/README.md
git commit -m "Enable release workflow"
git push
```

Before the workflow can sign a release build, add these four repository
secrets (Settings → Secrets and variables → Actions):

- `ANDROID_KEYSTORE_BASE64` - the upload keystore (`.jks`), base64-encoded.
- `ANDROID_KEYSTORE_PASSWORD` - the keystore's password.
- `ANDROID_KEY_ALIAS` - the key alias inside the keystore.
- `ANDROID_KEY_PASSWORD` - the key's password.

See the "Release" section of the top-level `README.md` for how to create the
keystore and encode it.

Tracked by the "Release signing config and tagged release workflow" issue in
milestone M9.
