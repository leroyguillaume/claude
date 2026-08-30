---
name: adr-conventions
description: Architecture Decision Record conventions — one immutable file per
  decision in `docs/adr/NNNN-kebab-title.md`, written when the decision is
  taken, superseded by a new ADR rather than edited. The one place in the repo
  where history belongs; `ARCHITECTURE.md` stays present-tense.
  TRIGGER when: taking or recording an architectural decision — adding or
  removing a component, datastore or external dependency, changing how parts
  communicate, accepting an outside constraint, deviating deliberately from a
  convention; creating or editing anything under `docs/adr/`; user asks
  whether something warrants an ADR, or where a decision should be written
  down.
  SKIP when: describing the system as it stands (that is
  `architecture-conventions`), or the decision is reversible in an afternoon
  and touches one module.
---

# ADR conventions

An **Architecture Decision Record** captures one decision, at the moment it is
taken, and is then frozen. It answers a question no other file can: *what did
we know, what else was on the table, and why did we pick this?*

**Always in English**, like every other document in the repository.

## The split with `ARCHITECTURE.md`

These two are complementary and must not drift into each other:

| | `ARCHITECTURE.md` | `docs/adr/` |
| --- | --- | --- |
| **Tense** | present — what *is* | past — what was decided, then |
| **Scope** | the whole system, coherent | one decision, isolated |
| **Lifecycle** | rewritten as the system changes | immutable once accepted |
| **History** | never | that is the point |

`ARCHITECTURE.md` is where history is banned precisely *because* the ADRs hold
it. Without them, the pressure to narrate the past leaks into the design doc
and rots it (see `architecture-conventions`).

**A decision that changes the design updates both, in the same commit**: the
ADR records what was decided, and `ARCHITECTURE.md` is rewritten to describe
the new state as though it had always been that way. `ARCHITECTURE.md` may
link an ADR as the record; it must never narrate the change.

## When to write one

The hard part, and where most ADR practices die — either nobody writes any, or
everything gets one and nobody reads them.

**Write an ADR when the answer to "why is it like this?" takes more than two
sentences *and* doing the opposite tomorrow would be expensive.** Concretely:

- a component, datastore or external dependency is added or removed;
- how the parts talk changes — protocol, sync to async, who owns what data;
- a choice between options where **the loser was genuinely credible**. If
  there was no real alternative, there was no decision, only a fact;
- a constraint accepted from outside — org policy, a platform limit, a quota,
  a compliance rule — that the design now bends around;
- a **deliberate deviation** from a convention in these skills or in the
  project's own rules.

**Do not write one for**: adding an endpoint or a screen, a dependency bump, a
refactor with no interface change, a naming choice, or anything a single
person can undo in an afternoon. A repository with forty ADRs has no ADRs.

**When in doubt, ask the user** whether the change warrants one — it is a
judgement about how permanent the decision feels, and they know that better
than the diff does.

## Files

- **`docs/adr/NNNN-kebab-case-title.md`** — four-digit zero-padded sequence
  from `0001`, allocated in order and **never renumbered**, never reused. A
  number is a permanent address: it is cited from `ARCHITECTURE.md`, from
  commit messages, from other ADRs.
- **The title states the decision, not the topic.**
  `0007-store-sessions-in-redis.md`, not `0007-session-storage.md`. Someone
  scanning the directory should read the decisions, not the agenda.
- **`docs/adr/README.md`** — the index: a table of number, title and status,
  updated in the same change. Undiscoverable ADRs get rewritten by accident.

## Template

```markdown
# NNNN. <the decision, as a sentence>

- **Status**: accepted
- **Date**: YYYY-MM-DD

## Context

What forced a decision: the constraint, the problem, what was already true.
Enough that someone who was not there can weigh the options themselves — and
no more. Facts, not the narrative of the meeting.

## Decision

What was decided, in the active voice: "we store sessions in Redis". A few
lines. This is the part people come back for.

## Consequences

What this makes easy, what it makes hard, and what it commits us to. The
negative half is not optional — an ADR listing only benefits is an
advertisement, and it is the part a future reader needs most.

## Alternatives considered

Each credible option, and the specific reason it lost. "Postgres: another
service to operate for a workload that fits in memory." One or two lines
each; an option nobody seriously weighed does not belong here.
```

Keep it to **one page**. Past ~150 lines it is usually several decisions
wearing one number — split it.

## Status and the immutability rule

`proposed` → `accepted` → `superseded by [ADR-NNNN](NNNN-….md)`, plus
`rejected` for a decision that was weighed and turned down.

**An accepted ADR is never edited again, except its `Status` line.** Not to
fix the reasoning, not to add what was learned, not to reflect how things
turned out. The record is of what was decided *then*, with what was known
*then*; edited in place it stops being a record and becomes a second, worse
`ARCHITECTURE.md`.

- **Changed your mind? Write a new ADR** that supersedes the old one, and set
  the old one's status to point at it. Both stay in the tree.
- **Never delete a superseded or rejected ADR**, and never renumber around a
  gap. The trail is the value — a rejected option that keeps coming up is
  answered by pointing at its ADR.
- Typos and dead links are the only free edits.

## Writing them for an existing project

Retro-fitting an ADR for every past decision is fiction, and reads like it.
When adopting ADRs in a repository that already exists:

- write ADRs only for the **load-bearing decisions still shaping the code**,
  the ones people keep re-litigating;
- date them the day they are written, not the day the decision was taken, and
  say in the Context that the decision predates the record;
- do not invent alternatives that were never weighed — leave the section out
  rather than fabricate a deliberation.

**Never:**

- Never edit an accepted ADR beyond its status line — supersede it instead.
- Never delete or renumber an ADR, superseded or rejected included.
- Never put a decision log inside `ARCHITECTURE.md`, and never let an ADR
  drift into describing the whole system.
- Never write an ADR for a reversible, local change.
- Never ship an ADR whose Consequences section lists only upsides.
- Never leave `docs/adr/README.md` out of date with the directory.
