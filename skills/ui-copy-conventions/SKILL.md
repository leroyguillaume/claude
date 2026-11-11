---
name: ui-copy-conventions
description: >-
  User-facing text in any interface: only the words a user needs to act.
  TRIGGER when: writing what a screen, form, dialog or terminal prompt says
  (labels, buttons, hints, empty states, errors) or a locale file (`locales/`,
  `*.po`, `strings.xml`); user says a UI is too wordy.
  SKIP when: the text is content the UI displays, or never shown to a user.
---

# UI copy conventions

Copy is every word an interface shows, on any platform. A generated interface
drifts towards more of it: an intro under each title, a hint under each field,
a sentence where a word does. **Write the least text that lets the user act
without guessing.**

## The test

Name the question the user has at that moment that a string answers ("what
goes here?", "why did it fail?"). No question, or already answered on screen →
delete it. Answered in too many words → cut it. When in doubt, leave it out: a
missing hint surfaces as a question, a needless one only slows every screen.

## No paraphrase

- **No intro restating the heading**: "Settings" needs no "Here you can manage
  your settings".
- **Helper text carries what the label cannot** — a format (`DD/MM/YYYY`), a
  constraint, a consequence — never the label again.
- **A tooltip carries only what is not on screen**: an icon-only control's
  name, or a truncated value in full.
- **No explanation of a standard pattern**: search field, close button,
  toggle, pagination.
- **No message restating what the screen shows**: no "Item deleted" toast when
  the item visibly disappears. Confirm only what the user cannot see, or offer
  "Undo".
- **One place per piece of information** on a screen.
- **No data that teaches nothing**: hide a column empty across the data set;
  say a value shared by every row once, in the heading ("Prices in EUR").

## Short labels

- **Buttons and menu items are a verb, plus its object when needed**, in one
  to three words: "Save", "Export CSV". Never "Click here to…" or "Please…".
- **A dialog's confirm button repeats its verb**: "Delete project?" →
  "Delete", not "OK".
- **Field labels and headings are nouns**: "Email", not "Please enter your
  email address".
- **A placeholder is never the label nor a copy of it**: an example value, or
  nothing.
- **Lead with the outcome**: "Failed: disk full", not "The export could not be
  completed because the disk is full".
- **Numbers over prose**: "3 files selected", not "You have selected three
  files".
- **One concept, one word**: not "Delete" here and "Remove" there, nor "View",
  "Open" and "Details" for one action.

## States and errors

- **Empty state**: one line on why, and the action that fills it — "No
  projects" and a "New project" button.
- **Loading**: a spinner or a skeleton; text only for a long wait, saying what
  is happening ("Importing 1,240 rows…").
- **An error says what happened and what to do**, next to where it happened:
  "Email already in use. Sign in instead?". No apology, no bare "Something went
  wrong", no stack trace: that goes to the logs (`logging-conventions`).
- **Confirm only destructive actions**, stating the consequence: "Delete
  project? Its 12 environments go too."
- **Terminals**: success prints the result or nothing, a prompt is the
  question alone, `--help` gives one line per option.
