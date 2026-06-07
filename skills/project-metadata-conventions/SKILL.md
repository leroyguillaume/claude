---
name: project-metadata-conventions
description: Project metadata conventions (derive author/maintainer and
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
