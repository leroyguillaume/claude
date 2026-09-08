---
name: diagram-conventions
description: >-
  Mermaid is the default diagram format, and inside a markdown file it is the
  answer — inline, in a fenced block, in the file that needs it. ASCII art is
  fine in chat and never in a committed file; Excalidraw and images are for
  what Mermaid genuinely cannot draw, committed with their editable source and
  never hosted outside the repo. Covers which diagram type answers which
  question, labelling edges, and keeping a diagram honest as the code moves.
  TRIGGER when: about to draw anything with boxes and arrows — a component
  graph, a call flow, a state machine, a sequence, an entity relationship, a
  deployment topology; typing `┌`, `─`, `│`, `+---+`, `-->` inside a fenced
  block; adding or editing a diagram in any document; a `.png`/`.svg`/`.drawio`
  /`.excalidraw` is about to be committed or linked as a diagram; user asks for
  a schema, a schéma, a diagram, or "draw me".
  SKIP when: the picture is a screenshot of a running UI, a photograph, or a
  generated plot of real data — those are images and stay images.
---

# Diagram conventions

**In a committed markdown file, a diagram is Mermaid, in a fenced ```mermaid
block, inline in the file that needs it.** That is the default, and it takes a
concrete reason — not a preference — to land anything else there.

Three reasons, and they are the whole rule:

- **It renders.** GitHub, GitLab, most IDE previews and the docs generators all
  draw Mermaid natively. Nothing to install, no build step, no CI job.
- **It diffs.** A reviewer sees `A --> B` become `A --> C` in the same patch as
  the code that moved. A picture shows a changed hash and nothing else.
- **It is editable by whoever touches it next.** Which is the actual failure of
  every other option: the person who has to update the diagram is never the
  person who has the source file, the licence, or the will.

Those three reasons are about a file somebody else will read and maintain. They
say nothing about a throwaway drawing in a conversation — hence the next
section.

## In chat, draw whatever is quickest to read

**An answer in the terminal is not a committed file: ASCII art is welcome
there.** Nobody has to maintain it, it will never wrap in a proportional font,
and half the time a five-line box sketch lands faster than a Mermaid block the
user has to render somewhere to see:

```
  client ──HTTP──> gateway ──gRPC──> worker
                      │
                      └──> cache (read-through)
```

Mermaid in chat is fine too, especially when the same diagram is about to be
written into a file. Pick per message; there is no rule to follow here beyond
"is this readable in a terminal".

**The moment it goes into a file, it becomes Mermaid.** Committed ASCII art is
still out, for the reasons it always was: it misaligns in a proportional font,
it cannot be edited without rebuilding the whole box, and it carries no
semantics — a reader cannot tell a queue from a database from a decision. If
you are counting spaces to line up a `│` *in a file*, stop and write Mermaid.

## When Mermaid is not the right tool

Mermaid draws graphs. It does not draw everything, and forcing it to is how you
get a `flowchart` pretending to be a floor plan. Reach for Excalidraw or an
image when the content is genuinely one of these:

- **A freeform sketch** — a whiteboard-shaped explanation where the spatial
  arrangement, the annotation and the scribbled aside *are* the content.
- **A UI wireframe or a screen flow.** Boxes on a canvas, at scale, with the
  layout carrying meaning.
- **Something physical or spatial** — a rack, a floor plan, a wiring layout, a
  network drawn geographically.
- **An annotated screenshot** of a real UI, a dashboard, a trace viewer.
- **A photograph, or a generated plot of real data.** Those were never
  diagrams; they are images and they stay images.

Two things this list is not. It is not "Mermaid was awkward, so I exported a
PNG" — a component graph, a sequence, a state machine and an ER model all have
a Mermaid type that fits, and the awkwardness is usually the diagram trying to
answer two questions at once. And it is not a licence to skip Mermaid in
markdown: even in a `.md` file the preference stands, and the picture has to
earn its place against the three reasons above.

### Committing one

- **Ship the editable source, in the repo.** An Excalidraw export with the
  scene embedded — `name.excalidraw.svg` or `name.excalidraw.png` — is one file
  that both renders on GitHub and re-opens in Excalidraw for editing. Prefer
  that over a bare `.excalidraw` (which renders nowhere) or a bare export
  (which edits nowhere). For anything else, the source sits beside the export
  and both move in the same commit.
- **Store it in the repository, next to the document that uses it**, and link
  it relatively — an image link whose target is
  `diagrams/reconcile-flow.excalidraw.svg`, say. A path that
  climbs out of the project root is wrong here for the same reason it is wrong
  anywhere else.
- **Never an externally hosted image** — a wiki, a Confluence page, a shared
  drive, an image CDN. A dead diagram waiting to happen, and invisible to
  anyone reading the repo offline or from a clone.
- **Write real alt text**: what the diagram shows, not `"diagram"`. It is what
  a screen reader, a plain-text diff and a failed image load all get.
- **Prefer SVG over PNG** where the tool offers it — it scales, it stays
  legible on a high-DPI screen, and it is text on disk.

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
  once and let Mermaid lay it out; hand-placing nodes in a graph the renderer
  could lay out itself is ASCII art with extra steps.
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
  more than prose. This is the cost an image carries and Mermaid does not —
  the update has to go through a tool, so it is the one that quietly rots.
- **Everything in it exists under that name in the repo.**

## Where diagrams belong

- **`ARCHITECTURE.md`** — the component graph and the flow that matters. This
  is the usual home; see `architecture-conventions`.
- **An ADR** — only when the decision *is* a shape, and then usually two small
  diagrams: what it looks like under the option taken, and under the one
  rejected. Mermaid, always: an ADR is immutable, so a diagram nobody can edit
  is one nobody can ever fix. See `adr-conventions`.
- **`README.md`** — normally not. A README carries commands, and a diagram
  there is a sign the description is drifting into design; link to
  `ARCHITECTURE.md` instead. See `readme-conventions`.
- **A merge request description** — freely, when it helps a reviewer see the
  change. It is not committed prose and does not have to survive.
