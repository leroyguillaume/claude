---
name: github-repo-settings
description: GitHub repository settings administered via the `gh` CLI — sync
  issue/PR labels to the set referenced in `.github/release.yaml`, restrict
  the allowed merge methods to squash-only, and auto-delete head branches on
  merge.
  TRIGGER when: the user asks to configure/clean up the GitHub repo's labels,
  align labels with the release changelog config, change which merge buttons
  (squash / merge commit / rebase) a repo allows, or toggle automatic
  head-branch deletion after merge.
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

`.github/release.yaml` only governs **PR labels** — the changelog generator reads
the labels on merged PRs, nothing else. So it is **not** the full set of labels a
repo should have. Two distinct purposes coexist:

- **Issue-triage labels** (`bug`, `enhancement`, `question`, `help wanted`, …):
  classify *reported* problems/requests. They legitimately exist even when absent
  from `release.yaml`. **Do not delete them just because the changelog config
  doesn't reference them.**
- **PR / changelog labels** (`feature`, `fix`, `chore`, `dependencies`, `rust`, …):
  classify the *change shipped*. These are what `release.yaml` maps to categories.

The same concept often has both: `bug` (issue) ↔ `fix` (PR), `enhancement` (issue)
↔ `feature` (PR). Inside one changelog category, listing both members of such a
pair is a duplicate — pick one (the PR-side label) and drop the other from
`release.yaml`; but keep the issue-side label alive on the repo.

The `"*"` catch-all in `release.yaml` is a wildcard, **not** a real label — never
create it.

Procedure:

1. Read `.github/release.yaml`, collect every concrete label it maps (drop `"*"`).
   These must all exist on the repo.
2. List current labels: `gh label list --limit 100`.
3. Create any release.yaml label that's missing. Add any repo label missing from
   release.yaml into the right category (or `exclude`) **if it's a PR label**;
   leave issue-triage labels out of `release.yaml` but keep them on the repo.
4. Only delete a label when the user actually wants it gone — never purely because
   it's absent from `release.yaml`.

```bash
unset GITHUB_TOKEN
# create / upsert the PR-changelog labels referenced by release.yaml (idempotent)
gh label create feature      --description "New feature"                  --color 0e8a16 --force
gh label create fix          --description "Bug fix"                      --color d73a4a --force
gh label create chore        --description "Maintenance / housekeeping"   --color fef2c0 --force
gh label create dependencies --description "Dependency updates"           --color 0366d6 --force
# issue-triage labels stay even though release.yaml never maps them
gh label create bug          --description "Something isn't working"      --color d73a4a --force
gh label create enhancement  --description "New feature or request"       --color a2eeef --force
gh label list --limit 100   # verify
```

Notes:

- `gh label create --force` upserts, so it is safe to re-run.
- Deleting a label removes it from every issue/PR it is on and **cannot be
  undone** — it is destructive. Absence from `release.yaml` is **not** a reason to
  delete; only do it when the user explicitly wants the label gone, and confirm
  the delete list first.
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

## Auto-delete head branches on merge

```bash
unset GITHUB_TOKEN
gh repo edit --delete-branch-on-merge
gh repo view --json deleteBranchOnMerge   # verify -> {"deleteBranchOnMerge":true}
```

Once on, merging a PR deletes its head branch automatically (the branch is still
recoverable from the PR's "Restore branch" button for a while). Pass
`--delete-branch-on-merge=false` to turn it back off.
