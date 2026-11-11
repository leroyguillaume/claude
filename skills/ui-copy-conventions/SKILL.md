---
name: ui-copy-conventions
description: >-
  User-facing text in any interface: only the words a user needs to act.
  TRIGGER when: building or editing a screen, form, dialog or terminal prompt;
  writing the labels, buttons, hints, empty states or errors it shows; editing
  UI strings or locale files (`locales/`, `*.po`, `strings.xml`); user says a
  UI is wordy or has too much text.
  SKIP when: the text is the content the interface displays (articles or user
  data) or is never shown to a user (logs and comments).
---

# UI copy conventions

Copy is every word an interface shows: headings, labels, buttons,
placeholders, helper text, tooltips, empty states, errors, confirmations,
toasts, terminal prompts and messages. These rules hold for every interface —
web, mobile, desktop, terminal, a generated page.

The user is there to do something, not to read. Every string costs attention,
and a generated interface drifts towards more of them: an intro under each
title, a hint under each field, a sentence where a word does. **Write the least
text that lets the user act without guessing.**

## The test: which question does this string answer?

Before keeping a string, name the question the user has at that moment that it
answers — "what goes here?", "what happens if I click?", "why did it fail?".

- **No question** → delete it.
- **Already answered on screen** — by the title, the label, the value itself,
  the state the UI shows → delete it.
- **Answered in more words than needed** → cut it down.

When in doubt, leave it out. A missing hint surfaces as a question someone
asks; a needless one never surfaces, it only makes every screen slower to
read. A sparse screen is not a problem to fill with text.

## No paraphrase

- **No intro sentence restating the heading.** "Settings" needs no "Here you
  can manage your settings". A description under a title is earned only by
  something the title cannot say: a consequence, a constraint.
- **No helper text repeating the label.** Helper text carries what the label
  cannot: a format (`DD/MM/YYYY`), a constraint ("At least 12 characters"), a
  consequence ("Visible to everyone in the workspace").
- **No tooltip on a control that has a visible label.** Tooltips are for
  icon-only controls, and then they name the action in a word or two.
- **No explanation of a standard pattern.** A search field, a close button, a
  toggle or a pagination control explains itself.
- **No message restating what the screen already shows.** No "Item deleted"
  toast when the item visibly disappears, no success dialog for a save the
  screen already reflects. Confirm only what the user cannot see: work done in
  the background, something sent elsewhere — or offer "Undo".
- **One place per piece of information** on a screen: not in the header, the
  card and the footer.

## Short labels

- **Buttons and menu items are a verb, plus its object when needed**, one to
  three words: "Save", "Delete project", "Export CSV". Never "Click here to…",
  "Please…", or a sentence.
- **A dialog's confirm button repeats its verb**: "Delete project?" →
  "Delete", not "OK" or "Yes".
- **Field labels and headings are nouns naming the thing**: "Email", not
  "Please enter your email address".
- **A placeholder is never the label**, since it disappears on input, and
  never repeats it ("Enter your email" in an "Email" field). Use it for an
  example value, or leave it empty.
- **Numbers and units over prose**: "3 files selected", not "You have selected
  three files".
- **One concept, one word**, everywhere: never "Delete" on one screen and
  "Remove" on the next for the same action.

## Empty, loading and error states

- **Empty state**: one line on why it is empty and the action that fills it —
  "No projects" and a "New project" button. No paragraph on what the feature
  is for.
- **Loading**: a spinner or a skeleton. Text only when the wait needs
  explaining, and then what is happening ("Importing 1,240 rows…"), never
  "Please wait while we…".
- **Errors say what happened and what to do**, in a sentence each at most,
  next to where it happened — a field's error under the field: "Email already
  in use. Sign in instead?". No apology, no "Something went wrong" alone, no
  internal detail (stack trace, exception name): that goes to the logs, see
  `logging-conventions`. An error code may follow the message when support
  needs it.
- **Confirm only destructive or irreversible actions**, and state the
  consequence rather than rephrasing the question: "Delete project? Its 12
  environments are deleted too."
- **Terminals follow the same rules**: a command that succeeds prints its
  result or nothing, a prompt is the question alone, `--help` gives one line
  per option.
