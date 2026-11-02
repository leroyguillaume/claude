---
name: github-pr-conventions
description: >-
  GitHub pull request labels with `gh`, as `.github/release.yaml` release
  notes read them.
  TRIGGER when: creating a pull request on GitHub (`gh pr create`), or fixing
  a PR's labels.
  SKIP when: a GitLab merge request; managing label definitions or merge
  methods (`github-repo-settings`); authoring workflow/release-note YAML
  (`github-actions-conventions`). Load `pr-conventions` alongside.
---

# GitHub pull request labels (`gh` CLI)

Rebasing, stacks, drafts, title and body are `pr-conventions`, which covers
GitHub and GitLab alike. This skill is the GitHub-only part: labels.

## Labels

**PR labels feed the generated release notes, so they follow
`.github/release.yaml`.** In a repo that has one, every PR carries its labels
from creation: an unlabelled PR lands in the "Other Changes" bucket and is
invisible to anyone scanning the changelog by category. **No `release.yaml`, no
label**: nothing reads them, so a category label there is noise on every PR.
That holds for `breaking` (the body already says what breaks) and for area
labels (the title's `area:` prefix already names the area). Bot PRs keep what
their config applies (see [Bot pull requests](#bot-pull-requests)).

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

## When the repo has `.github/release.yaml`

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
- **Never apply a category label that `.github/release.yaml` doesn't list.**
  A label that exists on the repo but is absent from `release.yaml` (`bug`,
  `enhancement`, a leftover from an old config) sorts nothing: the PR falls to
  "Other". The only labels allowed outside `release.yaml` are the area labels
  below.
- **Apply exactly one changelog-category label**, taken from
  `.github/release.yaml` — that file is the source of truth, and it differs
  from repo to repo: a repo without a `Documentation` category wants `chore`
  on a docs PR, and a repo without a `Maintenance` category sends `chore`
  straight to "Other". Match the labels that repo actually maps.
- **Add `breaking` on top of the category label when the PR breaks
  something** (the body says what breaks, see `pr-conventions`). It is the
  one label that stacks with the category label: `breaking` + `feature` lands
  under *Breaking changes* because that category comes first in
  `release.yaml`. If the repo has no `breaking` label or no *Breaking changes*
  category, don't drop the flag — say so (see below).
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

- **Bot PRs' labels come from the bot's config**, never by hand — see
  `dependency-update-conventions`.
- **Reuse Dependabot's ecosystem labels** (`rust`, `github_actions`, `docker`,
  …) verbatim as your area labels rather than a parallel set that means the
  same thing — see `github-repo-settings`.

## When the right label doesn't exist

Don't silently pick a wrong-but-present label to move on. If the repo lacks a
label the change clearly needs, say so and either (a) use the closest existing
category label and flag the gap, or (b) if the user wants the label created,
that's `github-repo-settings` work — labels should also stay in sync with
`.github/release.yaml`. Keep the `*` catch-all category as the fallback only;
never aim a PR at it on purpose.
