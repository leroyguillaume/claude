---
name: architecture-conventions
description: >-
  ARCHITECTURE.md conventions — a present-tense description of the
  system as it stands today (components, data flow, standing design
  trade-offs, invariants, limitations). Never a history: no past changes, no
  migrations, no changelog, no dated decision log. Never the CI.
  TRIGGER when: creating or editing `ARCHITECTURE.md`; a *why* paragraph shows
  up in the README or the README passes ~150 lines; adding a component, a
  datastore, an external dependency, or an invariant other code must respect;
  user asks how the system fits together, why a design choice was made, or
  where to document a trade-off.
  SKIP when: writing install/run/test instructions (that is
  `readme-conventions`), or documenting dev setup, pre-commit or the CI
  pipeline (that is `contributing-conventions`).
---

# ARCHITECTURE conventions

`ARCHITECTURE.md` answers **"why is it built like this, and how do the pieces
fit together?"** — for someone who is about to change the code and needs the
mental model first.

It is the *why* half of the split with the README (see `readme-conventions`);
the README keeps the commands. **Always in English.**

## The one rule that shapes everything: present tense only

**`ARCHITECTURE.md` describes the system as it is today. Nothing else.**

A reader must be able to trust every sentence as a statement about the current
code, without checking a date or wondering whether a paragraph is stale
folklore. The moment history creeps in, the file becomes an archaeology
exercise: the reader has to reconstruct which layer is still true.

So, never write:

- **past changes** — "the cache was moved to Redis", "the operator used to
  reconcile on a timer", "since v2.3 the API is versioned"
- **migration or bootstrap history** — how the cluster was first created, the
  order the tables were backfilled in, what the old schema looked like
- **a changelog or release notes** in any form, dated sections, "recent
  changes", "what's new"
- **a dated / superseded decision log** (ADR-style `Status: superseded by
  ADR-0007`). ADRs are how this repository records decisions, and they live
  one per file under `docs/adr/` with their own lifecycle — never inside this
  file. See `adr-conventions`
- **references to the change that introduced something** — PR numbers, commit
  hashes, ticket IDs as narrative

**Git already stores all of that**, with more precision and no maintenance
cost. Prose duplicating the log is prose that rots.

What git does *not* store is why a decision was taken over the alternatives on
the table that day — and that is what `docs/adr/` is for. The two files are
complementary: history is banned here precisely because the ADRs hold it. A
decision that **changes the architecture** lands in both, in one commit — a new
ADR, and this file rewritten to describe the new state. Linking an ADR from
here is fine; narrating the change is not. See `adr-conventions`.

Most decisions never reach that bar, and get no ADR at all — the ADR gate is
deliberately narrow (`adr-conventions`). **Their reasoning still belongs here**,
as standing rationale in the present tense: a chosen default, a file format, an
ergonomics call, a deliberate deviation from a convention. Say what the design
*is* and what the alternative could not do, and the fact that no ADR exists
costs nothing. Dropping the reasoning because it had nowhere else to go is how
a decision gets silently reversed a year later.

### The subtle distinction: standing rationale is not history

A rejected alternative is fair game **when the reasoning still holds today**,
because that is what stops the next person re-litigating it. Phrase it as a
present-tense property of the design, not as an event:

- ✅ "State lives in SQLite rather than PostgreSQL: the workload is
  single-writer and the deployment must run without an external database."
- ❌ "We migrated from PostgreSQL to SQLite in early 2025 because ops was
  tired of managing it."

Same fact, same usefulness — the first one is still true in three years, the
second one is a story about people who have left.

### When the architecture changes

**Rewrite the affected section so it describes the new state.** Do not append
a note, do not leave the old paragraph with a strikethrough, do not add a
"previously" clause. The diff of `ARCHITECTURE.md` *is* the history — that's
precisely why the file's contents don't need to be.

## What goes in

Adapt the order to the project; skip a section that has nothing real to say
rather than filling it with boilerplate.

```markdown
# Architecture

## Overview
## Components
## Data flow
## State and persistence
## Design decisions
## Invariants and constraints
## Limitations
```

- **Overview** — what the system is, in one paragraph, plus a diagram. Enough
  for a reader to place every later section.
- **Components** — one short block per component: its single responsibility,
  what it owns, what it explicitly does *not* do, and how it talks to its
  neighbours (protocol, sync/async, direction). Name them exactly as the
  directories and services are named in the repo, so the mapping to code is
  mechanical.
- **Data flow** — walk the two or three paths that matter end to end: the main
  request, the background/reconcile loop, the failure path. Say where
  retries happen, where the boundaries are transactional, and what is
  idempotent.
- **State and persistence** — where state lives, who owns each store, what the
  key entities are and how they relate. Schema *shape* and ownership, not a
  column-by-column dump the migrations already define.
- **Design decisions** — the choices a newcomer would otherwise question, each
  with its trade-off: what is gained, what is given up, and what the
  alternative could not do. A few paragraphs, present tense (see above).
  Include the tooling choices only when they shape the design.
- **Invariants and constraints** — what must hold for the system to be correct
  ("a reconcile handler never raises a permanent error", "IDs are ULIDs so
  they sort by creation"), and the constraints imposed from outside: org
  policy, platform limits, quotas, compliance rules. These are the sentences
  that save an afternoon; make them explicit and unmissable.
- **Limitations** — what the design does not handle, and what would have to
  change to lift it. Present tense: a limitation is a property of the
  system, not a promise about the future. No roadmap, no dates.

## What stays out

- **The CI.** Pipelines, workflows, runners, caching strategy, release
  automation, required checks — none of it belongs here. It is contributor
  tooling: see `contributing-conventions`. (The *artefacts* the system is
  built into — a static binary, a distroless image, a chart — are architecture
  and stay; the machinery that produces them is not.)
- **Commands.** Install, run, test, deploy → README. If a section here needs
  one, link to the README instead of repeating it.
- **Dev setup and code style.** → `CONTRIBUTING.md`.
- **Operational runbooks and one-off procedures** — how to recover from a
  corrupted store, how the cluster was bootstrapped. Those are `docs/`
  material; this file explains the design they operate on, not the steps.
- **API reference** — endpoint-by-endpoint listings belong in the OpenAPI
  document or generated docs. Describe the API's *shape* and boundaries here.
- **Duplication.** One home per fact; link across to the README and
  `CONTRIBUTING.md` rather than restating.

## Diagrams

- **Mermaid, inline in the file.** It renders on GitHub/GitLab, it diffs, and
  it doesn't rot in a binary nobody can edit.
- One diagram that shows the actual mechanism beats five decorative ones. A
  component graph plus one sequence diagram for the interesting flow covers
  most projects.
- Never link an image hosted outside the repo — an external host is a dead
  diagram waiting to happen.
- Label the edges (protocol, direction, sync/async). An unlabelled arrow says
  "these two things know about each other", which the reader had guessed.

## Links

**Relative inside the repo, `https://` URLs for anything outside it.** Linking
straight at the code this file describes is what keeps it verifiable —
`src/reconciler/`, `charts/app/values.yaml`, `README.md#configuration` are all
good targets. A path that climbs out of the project root is not: it describes
the author's directory layout rather than the project, and breaks for anyone
who clones elsewhere, in the GitHub/GitLab file viewer, and inside container
builds where the parent directory does not exist. An external system, a
standard, an upstream issue → its `https://` URL.

## Keeping it honest

- **Create it as soon as there is a second document's worth of content** — in
  practice, the first time a *why* paragraph appears in the README, or the
  README passes ~150 lines.
- **Cross-link both ways**: the README points here from the sections whose
  reasoning moved out; this file points at the README for commands. Check the
  anchors after a split — a moved heading takes its anchor with it.
- **Update it in the same change as the code**, and by rewriting, not
  appending.
- Every component, path and store named here must exist in the repo under that
  name. A section describing something that was renamed or removed is worse
  than no section: it lies with authority.
