---
name: diagram-conventions
description: >-
  Diagrams are Mermaid, inline in the file that needs them — never ASCII art,
  never a binary image, never an externally hosted picture. Covers which
  diagram type answers which question, labelling edges, and keeping a diagram
  honest as the code moves. Applies to every file in every repository:
  `ARCHITECTURE.md`, an ADR, a `docs/` page, a chart README, a merge request
  description, an answer in chat.
  TRIGGER when: about to draw anything with boxes and arrows — a component
  graph, a call flow, a state machine, a sequence, an entity relationship, a
  deployment topology; typing `┌`, `─`, `│`, `+---+`, `-->` inside a fenced
  block; adding or editing a diagram in any document; a `.png`/`.svg`/`.drawio`
  is about to be committed or linked as a diagram; user asks for a schema, a
  schéma, a diagram, or "draw me".
  SKIP when: the picture is a screenshot of a running UI, a photograph, or a
  generated plot of real data — those are images and stay images.
---

# Diagram conventions

**Every diagram is Mermaid, in a fenced ```mermaid block, inside the file that
needs it.** No exceptions worth the sentence it would take to argue for.

Three reasons, and they are the whole rule:

- **It renders.** GitHub, GitLab, most IDE previews and the docs generators all
  draw Mermaid natively. Nothing to install, no build step, no CI job.
- **It diffs.** A reviewer sees `A --> B` become `A --> C` in the same patch as
  the code that moved. A picture shows a changed hash and nothing else.
- **It is editable by whoever touches it next.** Which is the actual failure of
  every other option: the person who has to update the diagram is never the
  person who has the source file, the licence, or the will.

## What this replaces

- **ASCII art.** The tempting one, because it looks fine in the terminal you
  wrote it in. It then wraps at a different width, misaligns in a proportional
  font, cannot be edited without rebuilding the whole box, and carries no
  semantics — a reader cannot tell a queue from a database from a decision.
  If you are counting spaces to line up a `│`, stop and write Mermaid.
- **Committed `.png` / `.jpg` / `.svg` exports.** Dead the moment the tool that
  made them is not installed. If a `.drawio` or `.excalidraw` source sits beside
  the export, that is two artefacts to keep in step and one of them will drift.
- **Externally hosted images** — a wiki, a Confluence page, a shared drive, an
  image CDN. A dead diagram waiting to happen, and unreadable to anyone reading
  the repo offline or from a clone.
- **A wall of prose describing a topology.** If the paragraph is enumerating
  what talks to what, it is a diagram written badly.

## Pick the type that answers the question

| The question | The diagram |
| --- | --- |
| what are the pieces and what talks to what | `flowchart` |
| in what order, and who waits for whom | `sequenceDiagram` |
| what states can this be in, and what moves it | `stateDiagram-v2` |
| what are the entities and how do they relate | `erDiagram` |
| what runs where — nodes, zones, boundaries | `flowchart` with `subgraph` |
| what happens over calendar time | `gantt`, and only when dates are real |

**A component graph plus one sequence diagram for the interesting flow covers
most projects.** One diagram that shows the actual mechanism beats five
decorative ones; a diagram that only restates the section heading should be
deleted rather than improved.

## Making one worth reading

- **Label every edge.** An unlabelled arrow says "these two things know about
  each other", which the reader had already guessed. Put the protocol, the
  direction, and whether it is synchronous on it: `-->|"gRPC, streaming"|`,
  `-->|"register, TCP 9345"|`, `-.->|"async, at-least-once"|`.
- **Name nodes exactly as the repository names them.** A box called `worker`
  when the directory is `src/reconciler/` costs the reader the one mapping the
  diagram existed to give them.
- **Group with `subgraph` for real boundaries only** — a process, a host, a
  cluster, a trust boundary. Not for tidiness.
- **Quote every label**: `id["text"]`. It is what lets a label carry a colon,
  a comma, a slash or brackets without a parse error, and `<br/>` is how it
  gets a second line.
- **Direction: `TB` for a hierarchy or a stack, `LR` for a pipeline.** Choose
  once and let Mermaid lay it out; hand-placing nodes is ASCII art with extra
  steps.
- **Keep it renderable by the plain renderer.** No `%%{init}%%` theme blocks, no
  custom CSS classes, no fonts, no colour carrying meaning on its own — a
  reader in dark mode, in a terminal preview, or in a diff viewer has to get the
  same information. Colour may reinforce a grouping; it may never *be* the
  grouping.
- **A dozen or so boxes is the ceiling.** Past that, the diagram has stopped
  answering one question. Split it, or raise the altitude.

## Keeping it honest

A diagram is documentation, so every rule about documentation applies to it:

- **It describes the present.** No "will be", no "planned", no greyed-out box
  for the component nobody has built. See `architecture-conventions`.
- **It moves in the same commit as the code it describes.** A stale diagram is
  worse than none: it lies with authority and it lies in a form people trust
  more than prose.
- **Everything in it exists under that name in the repo.**

## Where diagrams belong

- **`ARCHITECTURE.md`** — the component graph and the flow that matters. This
  is the usual home; see `architecture-conventions`.
- **An ADR** — only when the decision *is* a shape, and then usually two small
  diagrams: what it looks like under the option taken, and under the one
  rejected. See `adr-conventions`.
- **`README.md`** — normally not. A README carries commands, and a diagram
  there is a sign the description is drifting into design; link to
  `ARCHITECTURE.md` instead. See `readme-conventions`.
- **A merge request description** — freely, when it helps a reviewer see the
  change. It is not committed prose and does not have to survive.
