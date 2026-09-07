---
name: project-metadata-conventions
description: >-
  Project metadata conventions (derive author/maintainer and
  repository/URL fields from `git config`, never invent them).
  TRIGGER when: setting or updating author/maintainer or repository/URL fields
  in any manifest (`Cargo.toml`, `pyproject.toml`, `package.json`,
  `Chart.yaml`, …) or in `README.md` clone instructions; scaffolding a new
  project's metadata; user asks where author/repo values should come from in
  this repo.
  SKIP when: no metadata/manifest field is being set and the user isn't asking
  about author/repository values.
---

# Project metadata (author / repository)

- **Derive author and repository metadata from `git config`, never invent
  it.** When you set or update author/maintainer or repository/URL fields in
  any manifest (`Cargo.toml`, `pyproject.toml`, `package.json`, `Chart.yaml`,
  `README.md` clone instructions, …), read the values from git:
  - **author**: `git config user.name` + `git config user.email` →
    `Name <email>`.
  - **repository**: `git config --get remote.origin.url`, normalised to the
    `https://` form (e.g. `git@github.com:owner/repo.git` →
    `https://github.com/owner/repo`).
- **If a needed value is not configured** (empty `user.name` / `user.email`,
  or no `origin` remote), **ask the user** for it — do not fall back to a
  guessed or placeholder value.

## A field that is already filled in is already correct

**This rule is about *writing* metadata, never about auditing it.** It applies
when a field is empty, or when you are the one setting it. A manifest that
already carries an author, a maintainer or a repository URL has had a human
decide it, and that decision needs no justification from me.

So, when `authors` / `maintainers` / `repository` already holds a real value:

- **Leave it alone, and say nothing.** Not in a review, not in an audit, not as
  a "worth checking" aside. A project has contributors, changes hands, and is
  routinely authored by someone other than whoever is sitting at the keyboard
  today — `git config user.name` is who is committing, not who owns the work.
- **A mismatch with `git config` is not a finding.** It is the normal state of
  any repository with more than one person in it. Never report it, never
  "flag it lightly", never ask about it in passing.
- **Only touch it when the user asks**, or when the same change is already
  rewriting that field for another reason.

An empty field, a placeholder (`Your Name`, `example.com`, a template's
leftovers), or a URL that does not resolve to the real remote is a different
matter — those are genuinely unset, and the rule above applies.
