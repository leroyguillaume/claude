---
name: pr-conventions
description: >-
  Pull requests and GitLab merge requests (`gh`, `glab`): rebasing, stacks,
  drafts, source-branch deletion, title and body.
  TRIGGER when: opening a PR or MR (`gh pr create`, `glab mr create`, an API
  call that creates one); marking one ready (`gh pr ready`,
  `glab mr update --ready`, dropping `Draft:` from an MR title); changing its
  base or target branch; opening, rebasing or retargeting a stack of
  dependent PRs or MRs; writing a PR or MR title or description.
  SKIP when: GitHub PR labels and release notes (`github-pr-conventions`), or
  repo settings (`github-repo-settings`). On GitHub, load
  `github-pr-conventions` alongside.
---

# Pull request conventions (`gh` and `glab`)

GitLab calls a pull request a merge request (MR), and its base branch the
target branch. Everything here applies to both; where the command differs, the
`glab` one stands beside the `gh` one. Labels on GitHub are
`github-pr-conventions`.

## Rebase onto its base before opening it

**A PR is opened from a branch that has just been rebased onto its up-to-date
base branch** — `main`, or the parent's branch for a stacked PR (see below) —
always, even when the branch is an hour old and the diff looks unrelated to
everything that landed since:

```bash
git fetch origin
git rebase origin/main
```

Before `gh pr create` / `glab mr create`, not after a reviewer trips over a
conflict marker. What it buys, and why "it'll merge fine anyway" is not a
reason to skip it:

- **The PR's diff is the change and nothing else.** A branch cut from a stale
  `main` drags everything that moved in between into the comparison, and the
  reviewer spends their attention telling the two apart.
- **CI runs against the code that will actually be merged.** Green on a
  three-week-old base says nothing about green on today's `main`; the failure
  then surfaces after the merge, where it is everybody's problem instead of
  mine.
- **Conflicts get resolved by whoever wrote the code**, while the reasons are
  still fresh, rather than by whoever hits the merge button.

**Rebase, never merge `main` into the branch.** A `Merge branch 'main' into …`
commit carries no information, and it makes the branch impossible to read as a
series of changes.

If the rebase conflicts, resolve it and **re-run the tests and the linters
before opening the PR** — a conflict resolution is fresh code that nothing has
checked yet. On a branch that was already pushed, force-push with
`--force-with-lease`, never a bare `--force`.

## An MR deletes its source branch on merge

**Every GitLab MR is opened with `--remove-source-branch`**, whatever the
project's default says — without it, `glab mr create` falls back to the
project setting, and merged branches pile up on the remote:

```bash
glab mr create --remove-source-branch --target-branch main --source-branch <branch> …
```

Through the API, that is `remove_source_branch: true`. On an MR opened
without it, check before fixing it: `glab mr update --remove-source-branch`
*toggles* the option, so running it on an MR that already has it turns it off.

```bash
glab mr view <iid> -F json --jq .force_remove_source_branch
glab mr update <iid> --remove-source-branch
```

Stacked MRs are safe: when a parent merges and its branch is deleted, GitLab
retargets the MRs based on it onto the parent's own target branch.

## A stacked PR is opened as a draft

**A PR whose base is another PR's branch — not the default branch — is opened
as a draft**, and stays a draft until everything under it has merged:

```bash
gh pr create --draft --base <parent-branch> --head <branch> …
```

```bash
glab mr create --draft --remove-source-branch --target-branch <parent-branch> --source-branch <branch> …
```

On GitLab, draft status is the `Draft:` title prefix: a title edit that drops
it — in the UI, `glab mr update --title` or the API — marks the MR ready.

The reason is the merge button. On a stacked PR it merges into the *parent's
branch*, not into the default branch:

- **The change silently folds into the PR below it**, which then carries two
  changes under one title and one description.
- **Its closing keyword never fires.** `Closes #123` only acts on a merge into
  the default branch, so the issue stays open with nothing left to close it.

Draft status is what makes that button unavailable while the stack is waiting.
A draft leaves the stack's dependency visible, and gets a normal review in the
meantime. Say in each stacked PR's description which PR it sits on.

Mark it ready only when its base is the default branch again: the parent has
merged, the PR has been retargeted, and the branch has been rebased onto it
(see above; with squash merges, `git rebase --onto origin/main
<old-parent-tip>`, so the parent's pre-squash commits are dropped):

```bash
gh pr edit <number> --base main
gh pr ready <number>
```

```bash
glab mr update <iid> --target-branch main
glab mr update <iid> --ready
```

**Read the base before marking anything ready** — one PR, or every PR of a
stack after rebasing it, one by one; never a batch marked ready from memory:

```bash
gh pr view <number> --json baseRefName --jq .baseRefName
```

```bash
glab mr view <iid> -F json --jq .target_branch
```

Anything but the default branch stays a draft. Only the bottom PR of a stack,
the one based on the default branch, is ever ready for review.

**A PR with others stacked on it tells their owners when it moves** —
rebased, force-pushed, or merged once the user says so — so they rebase in
turn. When another session owns them, that goes as a message
(`herdr-delegation`), not as a poll on their side.

If a stacked PR merged into its parent anyway, its change now ships with the
parent: move its closing keyword into the parent's description before the
parent merges, so the issue still closes.

## Title and body

- **The title follows the repo's commit-subject style** (read
  `git log --oneline`): a squash merge makes it the commit subject on the
  default branch.
- **Link the issue it resolves** with `Closes #123` in the body
  (`Closes group/project#123` for an issue in another GitLab project), so the
  merge into the default branch closes it. Never close an issue by hand on the
  user's behalf.
- **A follow-up spotted while opening the PR** goes in the body as
  `Follow-up: #123`, after the issue is opened (see
  `github-issue-conventions`) — never as a comment in the code.
- **A breaking change says what breaks, and how to migrate**, in the body — a
  removed or renamed API, CLI flag, env var, config key or chart value; a
  changed default, wire format or schema that needs a migration; a dropped
  platform or version. Anything that forces a user to change something to
  upgrade.
