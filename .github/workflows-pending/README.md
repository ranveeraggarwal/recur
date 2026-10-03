# Pending workflow

`release.yml` here replaces `.github/workflows/release.yml`. It adds format,
analyze and test steps before the release build, so a tag cannot ship a
broken build, and turns on generated release notes. It is not in
`.github/workflows/` because the credentials used to write it lack GitHub's
`workflow` scope. From a machine with normal push rights:

```sh
git mv -f .github/workflows-pending/release.yml .github/workflows/release.yml
git rm .github/workflows-pending/README.md
git commit -m "Gate releases on format, analyze and tests"
git push
```
