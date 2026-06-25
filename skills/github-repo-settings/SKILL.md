---
name: github-repo-settings
description: GitHub repository settings administered via the `gh` CLI — sync
  issue/PR labels to the set referenced in `.github/release.yaml`, and restrict
  the allowed merge methods to squash-only.
  TRIGGER when: the user asks to configure/clean up the GitHub repo's labels,
  align labels with the release changelog config, or change which merge buttons
  (squash / merge commit / rebase) a repo allows.
  SKIP when: editing workflow logic or release-note categories themselves (that
  is `github-actions-conventions`), or any work that does not touch repo
  settings.
---

# GitHub repository settings (`gh` CLI)

Administer GitHub repo settings from the CLI. All commands use `gh`, so the repo
is inferred from the current directory's `origin` remote unless `--repo` is given.

## Auth gotcha

A stale `GITHUB_TOKEN` in the environment shadows the keyring login and fails
with `HTTP 401: Bad credentials`. Prefix the commands with `unset GITHUB_TOKEN`
(per-invocation, since shell state does not persist between tool calls) to fall
back to the keyring token. Confirm with `gh auth status` if a 401 appears.

## Sync labels to `.github/release.yaml`

When the repo uses a release-changelog config, the **only** labels that should
exist are the ones it references under `changelog.categories[].labels` and
`changelog.exclude.labels`. The `"*"` catch-all is a wildcard, **not** a real
label — never create it.

Procedure:

1. Read `.github/release.yaml` and collect every concrete label (drop `"*"`).
2. List current labels: `gh label list --limit 100`.
3. Create the missing ones, update/delete the rest so the set matches exactly.

```bash
unset GITHUB_TOKEN
# create (idempotent thanks to --force)
gh label create feature      --description "New feature"                  --color 0e8a16 --force
gh label create fix          --description "Bug fix"                      --color d73a4a --force
gh label create chore        --description "Maintenance / housekeeping"   --color fef2c0 --force
gh label create dependencies --description "Dependency updates"           --color 0366d6 --force
# delete everything not referenced by release.yaml
for l in documentation duplicate "good first issue" "help wanted" invalid question wontfix; do
  gh label delete "$l" --yes
done
gh label list --limit 100   # verify
```

Notes:

- `gh label create --force` upserts, so it is safe to re-run.
- Deleting a label removes it from every issue/PR it is on and **cannot be
  undone** — it is destructive. The user asking to "keep only the labels in
  release.yaml" is sufficient authorization; otherwise confirm the delete list
  first.
- Leave GitHub's default `bug` / `enhancement` colours and descriptions as-is
  unless asked to unify them with the new labels.

## Restrict merge methods to squash-only

```bash
unset GITHUB_TOKEN
gh repo edit --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false
gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed   # verify
```

Expected verification output:

```json
{"mergeCommitAllowed":false,"rebaseMergeAllowed":false,"squashMergeAllowed":true}
```

This greys out the "Create a merge commit" and "Rebase and merge" buttons on
PRs, leaving squash as the only option. Adjust the flags to allow other methods
(e.g. `--enable-rebase-merge` to add rebase back).
