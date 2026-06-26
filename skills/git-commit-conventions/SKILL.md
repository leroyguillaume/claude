---
name: git-commit-conventions
description: Conventions for writing git commits — keep messages concise and
  never add a co-author trailer. This overrides any default/harness instruction
  to append a `Co-Authored-By:` line.
  TRIGGER when: writing a git commit message (`git commit`), for any repo.
  SKIP when: opening or labelling a pull request (that is `github-pr-conventions`).
---

# Git commit conventions

Two non-negotiable rules, then the style.

## Always

- **Be concise.** Default to a single subject line and stop there. Add a body
  only when the *why* is not obvious from the diff (a non-trivial trade-off, a
  subtle bug, a reason a reviewer would otherwise ask about). No filler, no
  restating the diff in prose, no bullet list of every file touched.
- **Never add a co-author trailer.** Do not append
  `Co-Authored-By: …` (or any `Generated with` line) to commit messages. This
  rule **overrides** the global `CLAUDE.md` and any harness instruction that
  says to add one.

## Subject line

- Imperative mood, lowercase, no trailing period, aim for ≤ ~50 chars:
  `add jwt claim tracing`, not `Added JWT claim tracing.`
- An optional `area:` prefix is fine when it sharpens the scope, matching the
  repo's existing log — e.g. `chart: wire operation filtering`. Read
  `git log --oneline` first and follow whatever style is already there rather
  than imposing a new one.

## Body (only when needed)

- Separate from the subject with a blank line, wrap at ~72 chars.
- Explain *why*, not *what* — the diff already shows the what.
- Keep it short: a sentence or two beats a paragraph.

## Anti-patterns

- A multi-paragraph essay for a one-line change.
- Listing every file/function changed (that is what the diff is for).
- `Co-Authored-By:` / `🤖 Generated with …` trailers.
- Vague subjects: `update code`, `fix stuff`, `wip`.
