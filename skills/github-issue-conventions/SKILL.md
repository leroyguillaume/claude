---
name: github-issue-conventions
description: Where work that remains goes on a GitHub-hosted repo — an issue
  opened with the `gh` CLI, proposed and never opened unasked, never a
  `TODO.md` / roadmap / status section in a committed file.
  TRIGGER when: you spot work that is out of the current scope (a bug, a
  follow-up, a cleanup, a missing test), when the user asks to file/track
  something, or when you are about to write remaining work into any file.
  SKIP when: the repo has no GitHub `origin` remote (say the work out loud in
  chat instead and stop), or when the work is small enough to just do now.
---

# GitHub issue conventions (`gh` CLI)

**Remaining work lives in an issue, never in the repo's files.** A committed
`TODO.md`, a "roadmap" heading, a `## Status` checklist — they all rot within a
month, conflict on every branch, and become a second, worse tracker sitting next
to the real one. See the documentation rule in `~/.claude/CLAUDE.md`: a
document describes the present.

**GitHub only.** Everything here assumes an `origin` remote on GitHub — check
before reaching for `gh`:

```bash
git remote get-url origin
```

If the repo is not on GitHub, there is no issue to open: tell the user what you
found, in chat, and stop. Do **not** fall back to writing it in a file.

## Never open an issue unasked

Opening an issue is a public, outward-facing act on the user's account, exactly
like a commit or a push. Same rule: **propose, then wait for an explicit yes.**

Present it ready to run — title, body, labels — and let the user say go:

```bash
gh issue create \
  --title "handle a 429 from the credentials API" \
  --body "$(cat <<'BODY'
`sync_secret` in `src/reconcile.rs:88` treats every non-2xx as fatal, so a
rate-limited call burns the retry budget instead of backing off.

Done when a 429 is retried with the `Retry-After` delay and covered by a test.
BODY
)" \
  --label bug --label rust
```

The permission does not carry forward: the next issue needs its own ask.

## Before creating one, look for it

Issues duplicate easily, and a duplicate is worse than none — it splits the
discussion in two.

```bash
gh issue list --search "429 rate limit" --state all --limit 20
```

If it already exists, add a comment to it rather than opening a twin.

## Title

Same shape as a commit subject, for the same reason — it is read in a list of
fifty:

- Imperative mood, lowercase, no trailing period, aim for ≤ ~70 chars.
- An optional `area:` prefix when it sharpens the scope, matching the repo's
  existing issues. Read `gh issue list --limit 30` first and follow the style
  that is already there rather than imposing a new one.
- Say the thing, not the feeling: `retry a 429 from the credentials API`, not
  `improve error handling`.

## Body

Three short parts, and nothing else:

1. **What is true today** — the behaviour or the gap, with the file and line
   that show it (`src/reconcile.rs:88`). Present tense, no narrative of how it
   got there.
2. **Why it matters** — the consequence for a user or an operator, one
   sentence. If you cannot name one, the issue may not be worth opening.
3. **Done when** — the observable condition that closes it, including the test
   that proves it. This is what stops an issue from living forever.

No essay, no speculative design, no task breakdown invented on the spot. Link
the ADR, PR or upstream issue when one exists instead of restating it.

## Labels

Read the repo's real labels and use them verbatim — a name that does not exist
silently fails to apply:

```bash
gh label list --limit 100
```

Then apply one category label (`bug` / `feature` / `enhancement` / `chore` / …)
plus the area or technology labels that fit, exactly as in
`github-pr-conventions`. Never invent a label to fit the issue; creating one is
deliberate `github-repo-settings` work. If the right label does not exist, use
the closest one and say so.

## Closing the loop

- **Reference, do not duplicate.** A follow-up spotted while opening a PR goes
  in the PR body as `Follow-up: #123`, not as a comment in the code.
- **Let the PR close it.** Put `Closes #123` in the pull request body when the
  change actually resolves it. Never close an issue by hand on the user's
  behalf.
- **Nothing stays behind in the code.** No `TODO`, no `FIXME`, no `XXX` — not
  even one carrying the issue number. The issue is the marker; a second copy
  in a comment only adds one more thing that goes stale and lies. Once the
  issue exists, the code says nothing about it.
