---
name: documentation-conventions
description: >-
  Docs a human can maintain: one home per fact, links not copies.
  TRIGGER when: creating, splitting or restructuring docs (READMEs,
  ARCHITECTURE.md, docs/, runbooks); a README per directory or component; an
  index, table or list enumerating components, files or versions; user says
  docs are too long or drift; moving or deleting a repeated claim.
  SKIP when: a wording or typo fix that changes no claim and adds no list.
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
"what a cluster does differently is in `clusters/<cluster>/<project>/<app>/README.md`".
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

**No inventories of files.** A README does not list the files beside it, nor
what each one holds: the person adding or changing a file edits that file, not
the README next to it, and a "what it holds" column is a summary of the file's
own header. What a file does belongs in its header comment. A README says what
the directory is *for*, and names a file only where the prose needs it — the
one that is somewhere a reader would not look, the one a procedure edits.

**Similar is not the same.** Before merging near-identical text from several
places, ask whether it changes *together*. A procedure that belongs to one
environment — its bootstrap, its access, its recovery — changes with that
environment, so it stays whole in that environment's doc even when the others
look alike today: a shared version would have to be read against every one of
them, and the first divergence splits it again. Extract only what is the same
thing by construction — the design reason behind a step goes once in the
architecture doc, the step itself stays where it is run.

**Leave nothing contradicting what you wrote.** An edit does more than add a
sentence: it can make a sentence three files away false, and the page you are
editing is not the only one that talked about the thing you changed. Before
calling the change done, look for every page that mentions it — grep the term,
the file name, the command, the value — and read what each one claims, including
the rest of the page in front of you. Two pages disagreeing is worse than either
being wrong on its own: the reader cannot tell which is stale, so they trust
neither, and the next person "fixes" the one that was right. Resolve it in the
same change — correct the other page, or delete its copy and link to the home of
the fact.

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
- For each claim you changed, moved or deleted: grep the term and read every
  other page that mentions it. One that now says the opposite is fixed here, not
  left for a reader to arbitrate.
- Check every relative link and anchor still resolves — a split moves headings,
  and dead anchors are its usual casualty.
- Check that comments in code pointing at a doc section ("see the README's DNS
  section") still point at where that section now lives.
