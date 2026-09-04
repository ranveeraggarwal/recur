# Pending workflow

`ci.yml` here is the finished CI workflow. It could not be pushed to
`.github/workflows/` from the planning session because the credentials used
there lack GitHub's `workflow` scope. Move it into place from a machine with
normal push rights:

```sh
git mv .github/workflows-pending/ci.yml .github/workflows/ci.yml
git rm .github/workflows-pending/README.md
git commit -m "Enable CI workflow"
git push
```

Tracked by the "Enable CI workflow" issue in milestone M1.
