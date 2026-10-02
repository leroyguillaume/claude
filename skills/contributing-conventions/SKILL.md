---
name: contributing-conventions
description: >-
  CONTRIBUTING.md: dev setup, tests, pre-commit and CI.
  TRIGGER when: creating or editing `CONTRIBUTING.md`; scaffolding a project;
  a change adds a dev dependency, pre-commit hook or CI job; user asks how
  contributors set up the repo or where to document the CI.
  SKIP when: writing `README.md` (`readme-conventions`), or the workflow/hook
  files themselves (`ci-conventions`, `pre-commit-conventions`).
---

# CONTRIBUTING conventions

A `CONTRIBUTING.md` answers one question: **"I want to change this code — how
do I get a working setup and land a green PR?"** It is the *contributor's*
counterpart to the README's *user* view, and it is linked from the README (see
`readme-conventions`).

**Always in English.** Keep it operational: commands, not philosophy.

## Mandatory structure

```markdown
# Contributing

<One or two sentences: how to reach the maintainers, and the short version.>

## Development setup

## Running the tests

## Pre-commit hooks

## Continuous integration

## Submitting a change

## Releasing
```

`Releasing` only when the project cuts releases; every other section is
mandatory.

### 1. Development setup — what to install

Everything a contributor needs that a *user* does not. The README covers
running the project; this covers building on it.

- **List the tooling with versions**, and how to get it — the toolchain
  (`rustup`, `uv`, `node`), the package manager, `pre-commit` itself, and any
  binary the hooks or tests shell out to (`sqlfluff`, `helm`, `terraform`,
  `hadolint`, `trivy`). If a hook needs a binary that isn't installed, the
  contributor discovers it as a cryptic failure — list it here instead.
- **Give the bootstrap as a copy-pasteable sequence**, in order, from a fresh
  clone:

  ```bash
  uv sync --all-extras
  ```

  ```bash
  pre-commit install
  ```

  One command per fenced block, no `$` prompt, no interleaved output.
- **Every install command covers macOS *and* Linux** — `readme-conventions`
  carries the rule and the example.
- **Say what "it works" looks like** — the one command that proves the setup
  is good, and point at the test section below for the rest.
- **Do not restate the README.** How to *run* the project, its environment
  variables, its config — those live in the README. Link to it:
  `See [README.md](README.md#getting-started) for running the project.`
- Mention the editor/LSP setup only when it is genuinely required (a
  `pyrightconfig.json`, a rust-analyzer setting the code depends on), never as
  a list of the maintainer's favourite plugins.

### 2. Running the tests

**The test commands live here, not in the README** — running the suite is a
contributor's loop, not a user's. Give them verbatim, from the repo's actual
tooling:

- **The whole suite**, the one command that must be green before a PR:

  ```bash
  uv run pytest
  ```

- **A subset**, because nobody runs the full suite on every save — a single
  file, a single test, a marker or feature flag:

  ```bash
  uv run pytest tests/test_parser.py::test_rejects_empty_input
  ```

- **The categories that exist and how they differ** — unit vs integration vs
  end-to-end — and crucially **what each one needs**: a running database, a
  cluster, a container runtime, credentials for a sandbox account. A test
  suite that silently requires Docker is a contributor's lost afternoon.
- **How to run the slow or optional ones**, and how they're excluded by
  default (a marker, a feature, an environment variable).
- **Coverage**, only if the project actually enforces a threshold — the
  command and the number. Don't document a coverage tool nobody gates on.
- **What is expected of a new change**: tests for new behaviour, a regression
  test for a fix. Say it once, here.

If a test needs fixtures, seed data, or a `docker compose up` first, that
command belongs in this section too — a contributor should never have to
reverse-engineer a failing test to discover it needed a service.

### 3. Pre-commit — the gate

Every repo has a `.pre-commit-config.yaml` with the baseline hooks and those
for each technology in use (`pre-commit-conventions`); this section is how a
contributor lives with it.

- **`pre-commit install` is part of the setup**, and say plainly that hooks
  must pass before a commit is pushed.
- **Give the two commands**: the whole repo, and re-running a single hook
  while iterating.

  ```bash
  pre-commit run --all-files
  ```

  ```bash
  pre-commit run <hook-id> --all-files
  ```

- **List the hooks and what they enforce**, briefly — derive the list from the
  repo's actual `.pre-commit-config.yaml`, never from memory. A short table
  (hook → what it checks → how to fix) beats prose; formatters mostly fix
  themselves on re-run, linters don't.
- **Say that `--no-verify` and `SKIP=` are not the fix.** A red hook is a real
  finding; the answer is to fix the code or, if the rule is genuinely wrong for
  this repo, to change the configuration in the same PR and say why.
- Note that the same hooks run in CI (see below), so skipping locally only
  moves the failure somewhere slower.

### 4. Continuous integration — what runs and why

**Describe the pipeline that actually exists.** Read
`.github/workflows/*.yaml` (or the equivalent) and document what's there —
never a generic "we run tests on every PR" that drifts from reality within a
month.

For each workflow, cover four things: **when it triggers, what it does, what
it blocks, and how to reproduce it locally.** A table carries this well:

```markdown
| Workflow | Triggers on | What it does | Reproduce locally |
| --- | --- | --- | --- |
| `quality.yaml` | every PR | `pre-commit run --all-files`, unit tests | `pre-commit run --all-files` |
| `build.yaml` | every PR, `main` | builds the image, `trivy` scan | `docker build .` |
| `security.yaml` | every PR, `main`, daily | `trivy fs`, `trivy image` on the latest release | `trivy fs .` |
| `release.yaml` | tag `v*` | publishes image + chart | — |
```

Then, in a few lines:

- **Which checks are required** to merge, and which are informational.
- **The local equivalent of every blocking check** — a contributor should
  never need to push to find out whether it passes. If a check genuinely has
  no local equivalent (a signed publish, a cluster-integration job), say so
  explicitly rather than leaving people guessing.
- **What secrets or permissions the pipeline needs**, by *name and purpose*
  only — never a value, never a token, not even a truncated one. Fork PRs
  usually can't see them; say which jobs are therefore skipped.
- Keep the *why* to a line. That the release job builds on native runners and
  takes twelve minutes is CI documentation; why it uses them instead of QEMU
  is one sentence here or in the workflow file's header comment — never
  `ARCHITECTURE.md`, which leaves the CI out.

### 5. Submitting a change

Short and concrete:

- Branch naming, if the repo has a convention.
- **Commit style** — imperative, lowercase subject; point at the existing
  `git log --oneline` as the reference rather than inventing rules.
- **PR expectations** — green CI, documentation updated in the same PR, and
  the labels the repo uses (see `github-pr-conventions`). The testing
  expectation is stated once, in the test section; don't repeat it here.
- How reviews happen and who to ping, when there is an actual answer.

### 6. Releasing — only when the project cuts releases

How a maintainer cuts one, commands only: the release script to run and what
it asks before pushing, and which CI workflow publishes from the tag. The
script is the only supported way to release — say so here
(`release-script-conventions`).

## Links

Relative inside the repo, `https://` URLs outside it, never a path climbing
out of the project root — and link the workflow and config files described, so
a hook is one click from its definition.

## Keeping it honest

- **Update it in the same change** that adds a dev dependency, a hook, or a CI
  job. A setup section that misses a newly required binary costs every future
  contributor the same twenty minutes.
- **Never duplicate the README or `ARCHITECTURE.md`.** One home per fact; link
  across. Setup and gates here, usage in the README, design reasoning in
  `ARCHITECTURE.md` — created if it does not exist yet.
- **Every command must work from a fresh clone**, in the order written. Run
  them if you can.
- Skip the boilerplate. A code of conduct is a separate file
  (`CODE_OF_CONDUCT.md`) if the user wants one — don't inline a template, and
  don't add one unasked.
