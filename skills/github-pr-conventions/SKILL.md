---
name: github-pr-conventions
description: Conventions for opening GitHub pull requests with the `gh` CLI —
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
- **Read the repo's actual labels — never invent or guess names.** List them
  first and use the names that exist verbatim:
  ```bash
  gh label list --limit 100
  ```
  A label name that isn't in the list silently fails to apply. Creating new
  labels is a separate, deliberate act (see `github-repo-settings`); do not
  conjure one mid-PR.
- **Apply at least one changelog-category label.** When `.github/release.yaml`
  exists, its `changelog.categories` define which labels sort a PR into a
  release-notes section — read it and pick the matching one. The common mapping:

  | Change | Category label(s) |
  | --- | --- |
  | New capability / feature | `feature` (or `enhancement` if extending existing behaviour) |
  | Bug fix | `fix` (or `bug`) |
  | Refactor, CI, docs, build, housekeeping | `chore` |
  | Dependency bump | `dependencies` |

- **Add the area / technology labels that apply** on top of the category label.
  E.g. a PR touching Rust code gets `rust` as well as `feature`/`fix`/…; a
  dependency PR may carry both `dependencies` and the relevant tech label. A PR
  typically ends up with **two-ish** labels: one category + one or more area.

## Choosing the labels

Look at the diff, not the branch name:

- A PR that adds a user-facing capability → `feature`. One that improves or
  extends something already shipped → `enhancement`. When the repo has both and
  they map to the same release-notes category, prefer the one that best
  describes the change; don't apply both.
- A PR that fixes incorrect behaviour → `fix`/`bug`.
- A PR that only refactors, updates CI/docs/build, or does maintenance with no
  behavioural change → `chore`.
- A PR whose substance is bumping dependencies → `dependencies`.
- Then add every applicable area label (language, component) the repo defines.

## When the right label doesn't exist

Don't silently pick a wrong-but-present label to move on. If the repo lacks a
label the change clearly needs, say so and either (a) use the closest existing
category label and flag the gap, or (b) if the user wants the label created,
that's `github-repo-settings` work — labels should also stay in sync with
`.github/release.yaml`. Keep the `*` catch-all category as the fallback only;
never aim a PR at it on purpose.
