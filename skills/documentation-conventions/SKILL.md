---
name: documentation-conventions
description: >-
  Documentation must stay maintainable by a human without an LLM: one home per
  fact, links instead of copies, no fan-out lists that every new component has to
  be added to, no summaries of other docs, nothing a config file already says.
  The test for every sentence: which change makes it false, and will the person
  making that change find it? TRIGGER when: creating, splitting or restructuring
  documentation — READMEs, ARCHITECTURE.md, docs/, runbooks; adding a README per
  directory, component, app or environment; writing an index, a table or a list
  that enumerates components, files, clusters, versions or settings; user says
  the docs are too long, too hard to maintain, or drift. SKIP when: the change is
  a one-line fix to an existing sentence that does not add a list, a table or a
  copy.
---

# Documentation conventions

Documentation is maintained by people, by hand, months later, in a hurry. A doc
that is only correct as long as an LLM regenerates it is a doc that will lie.
**Write every page so that a human making an ordinary change to the code knows,
without searching, which doc sentences that change affects — and there are few
of them.**

The other conventions say *what* goes where (`readme-conventions`,
`architecture-conventions`, `contributing-conventions`) and that docs describe
the present. This one is about the *cost of keeping them true*.

## The test: which change makes this false?

For every sentence, table row and list item, ask:

1. **What change to the repository makes it false?** A new component, a renamed
   file, a version bump, a label flipped, a value edited.
2. **Will the person making that change see it?** Only if it sits in the file
   they are editing, or right next to it — the same directory, the README of the
   thing they touch.

If the answer to 2 is "only if they grep the whole repo", the sentence is a
liability. Delete it, move it next to what it describes, or replace it with a
link to the source of truth.

## Rules

**One home per fact; everything else links.** A fact is written once, where it
is paid for — next to the code or config it describes. Other pages point to it.
Never paraphrase another doc "for convenience": the paraphrase drifts and the
reader cannot tell which one is wrong.

**No fan-out lists.** A list that grows with every new sibling is a list someone
forgets to update. Typical offenders:

- each component's README listing every environment it runs in, when each
  environment already has a directory per component;
- each environment's README repeating the catalog of components;
- a "per cluster / per app / per service" section in N files, when adding the
  N+1th thing should touch one.

Point from the many to the one with a **pattern** instead of an enumeration:
"what a cluster does differently is in `clusters/<cluster>/<app>/README.md`".
**Adding a component or an environment should touch its own new files and at
most one index**, never every sibling's docs.

**One index per collection, and only one.** A collection (apps, services,
clusters, modules) gets a single list, in the README of the directory that holds
them. Nowhere else lists them. A row may carry one line saying what the item
*is* — that only changes if the item becomes something else — never what it
currently does differently, which is what changes.

**No summaries of other pages.** A table column that summarises what a linked
page says ("Specifics", "Notes", "Status") is a second copy of that page. Link
the page; let it speak for itself.

**Do not restate configuration.** Versions, chart names, namespaces, feature
flags, enabled/disabled switches, image tags, ports — if a config file holds it,
the doc links the file and says *why* the value is what it is, never *what* it
is. The one exception: a value a reader needs to type (a hostname, a command
argument) in a procedure.

**No state.** "Deployed", "not applied yet", "live", "pending", "done" — see the
global rule on present-tense docs. State is the extreme case of a fact nobody
will remember to update.

**Inventories only next to what they list.** A table of the files in a directory
belongs in that directory's README — the person adding a file is standing right
there. An inventory of something that lives elsewhere does not.

**Similar is not the same.** Before merging near-identical text from several
places, ask whether it changes *together*. A procedure that belongs to one
environment — its bootstrap, its access, its recovery — changes with that
environment, so it stays whole in that environment's doc even when the others
look alike today: a shared version would have to be read against every one of
them, and the first divergence splits it again. Extract only what is the same
thing by construction — the design reason behind a step goes once in the
architecture doc, the step itself stays where it is run.

**Link, do not describe, what sits in another repository.** Point at the
infrastructure repo, the upstream doc, the ticket. A description of someone
else's system is a copy of it.

## Sizing

A README a human can review in one sitting: aim under ~200 lines, and treat 400
as a split signal. When a page is long, the fix is usually one of the rules
above (copies, summaries, restated config), not a new page. Split by *owner of
the change*: what changes together lives together.

## Before finishing a documentation change

- For each new list or table: name the change that adds a row, and check the
  person making it will be editing this file anyway.
- Grep for the facts you wrote in more than one place; keep one, link from the
  rest.
- Check every relative link and anchor still resolves — a split moves headings,
  and dead anchors are its usual casualty.
- Check that comments in code pointing at a doc section ("see the README's DNS
  section") still point at where that section now lives.
