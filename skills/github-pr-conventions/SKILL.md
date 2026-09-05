---
name: github-pr-conventions
description: >-
  Conventions for opening GitHub pull requests with the `gh` CLI —
  always apply the right labels at creation time so the PR lands in the correct
  release-notes category. Derive the label set from the repo (and
  `.github/release.yaml`), never from memory.
  TRIGGER when: creating/opening a pull request (`gh pr create`), or fixing an
  existing PR's labels.
  SKIP when: managing the repo's label *definitions* or merge methods (that is
  `github-repo-settings`), or authoring workflow/release-note YAML (that is
  `github-actions-conventions`).
---

# GitHub pull request conventions (`gh` CLI)

**Every PR you open must carry the right labels, applied at creation time.** An
unlabelled PR lands in the "Other Changes" bucket of the generated release notes
and is invisible to anyone scanning the changelog by category. Labelling is part
of opening the PR, not an afterthought.

## How GitHub actually sorts a PR

The generated notes put a PR in the **first category whose label set matches, in
the order the categories appear in `.github/release.yaml`** — one PR, one
section. Two consequences that drive every choice below:

- **Extra category labels are silently ignored, not additive.** A PR carrying
  both `feature` and `fix` shows up once, under whichever category comes first
  in the file. So pick the one that describes the change; don't hedge by
  applying two.
- **A PR that is genuinely two changes is two PRs.** If you cannot name one
  category without lying, split it rather than picking the bigger half.

## Always

- **Pass `--label` on `gh pr create`** — do not open the PR first and label it
  later (you usually forget). Repeat the flag per label:
  ```bash
  gh pr create --base main --head <branch> \
    --title "…" --body "…" \
    --label feature --label rust
  ```
  If you genuinely opened a PR without labels, fix it immediately with
  `gh pr edit <number> --add-label <name> [--add-label <name>]`.
- **Read the repo's actual labels and its categories — never invent or guess
  names.** Both, before writing the command:
  ```bash
  gh label list --limit 100        # what exists
  cat .github/release.yaml         # what it maps to, and in which order
  ```
  `gh` does not create a label on the fly: a name that isn't in the list fails
  the whole command with `labels not found: <name>`. Creating new labels is a
  separate, deliberate act (see `github-repo-settings`); do not conjure one
  mid-PR.
- **Apply exactly one changelog-category label**, taken from
  `.github/release.yaml` — that file is the source of truth, and it differs
  from repo to repo. The table below is only the fallback for a repo that has
  no `release.yaml` yet:

  | Change | Category label |
  | --- | --- |
  | Backwards-incompatible change | `breaking` |
  | Security fix | `security` |
  | New capability | `feature` |
  | Bug fix | `fix` |
  | Documentation only | `documentation` |
  | Dependency bump | `dependencies` |
  | Refactor, CI, build, housekeeping | `chore` |

  Read the repo's categories rather than applying this table blind: a repo
  without a `Documentation` category wants `chore` on a docs PR, and a repo
  without a `Maintenance` category sends `chore` straight to "Other". Match the
  labels that repo actually maps.

- **Add the area / technology labels that apply** on top of the category label.
  Area labels never select a category on their own, so they are safe to stack:
  a Rust PR gets `rust` as well as `feature`/`fix`/…. A PR typically ends up
  with **two-ish** labels: one category + one or more area.

## `bug`/`enhancement` are issue labels, not PR labels

`bug` and `enhancement` classify a *reported* problem or request; `fix` and
`feature` classify the *change shipped* (see `github-repo-settings`). On a PR,
reach for `fix`/`feature` by default. Use `bug`/`enhancement` on a PR **only**
when that repo's `release.yaml` genuinely maps them — and when it maps both
members of a pair into one category, say so: that is a duplicate to clean up,
not a choice to make per PR.

## Keeping a PR out of the changelog

A repo whose `release.yaml` has an `exclude.labels` entry can drop a PR from the
notes entirely. **Use the name that repo already defines** —
`ignore-for-release` is the default for a new repo; `skip-changelog` exists in
older ones and is equally fine where it is already in use. Don't introduce a
second name into a repo that has one.

Reach for it sparingly: a merged PR is a change that shipped, and the honest
default is to let it appear under some category. It is for the genuinely
non-shipping ones — a revert of something that never made a release, a
changelog-only or release-plumbing PR.

## Bot pull requests

- **Dependabot and Renovate label their own PRs** (`dependencies`, plus the
  ecosystem label). Leave them alone: relabelling a bot PR by hand achieves
  nothing the bot didn't already do.
- **Dependabot creates its ecosystem labels itself** — `rust`,
  `github_actions`, `docker`, `python`, `npm_and_yarn` — all black
  (`#000000`), described as "Pull requests that update … code". They show up
  in `gh label list` without anyone having asked. Reuse those names verbatim as
  your area labels rather than creating a parallel `Rust`/`ci` set that means
  the same thing.

## When the right label doesn't exist

Don't silently pick a wrong-but-present label to move on. If the repo lacks a
label the change clearly needs, say so and either (a) use the closest existing
category label and flag the gap, or (b) if the user wants the label created,
that's `github-repo-settings` work — labels should also stay in sync with
`.github/release.yaml`. Keep the `*` catch-all category as the fallback only;
never aim a PR at it on purpose.
