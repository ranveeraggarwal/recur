# Pending workflow

`release.yml` here replaces `.github/workflows/release.yml`. It adds a
`permissions: contents: write` block, so the release job can publish without
the repo-wide "Read and write permissions" setting. It is not in
`.github/workflows/` because the credentials used to write it lack GitHub's
`workflow` scope. From a machine with normal push rights:

```sh
git mv -f .github/workflows-pending/release.yml .github/workflows/release.yml
git rm .github/workflows-pending/README.md
git commit -m "Give the release workflow write access to contents"
git push
```

After that, the repo's workflow permissions setting can go back to read-only.
