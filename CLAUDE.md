# CLAUDE.md

Global, non-negotiable rules for Claude Code. These apply to **every** project
unless a project-level `CLAUDE.md` explicitly overrides a specific rule.

Most concrete conventions live in skills under `~/.claude/skills/`, which load
on demand from file paths and topics (see the list at the end). The rules kept
in this file are the ones that must apply unconditionally — meta-principles and
negative guardrails that would be dangerous to miss if a skill failed to load.

## Non-negotiable rules

These are not suggestions. If a project is missing any of the artifacts below,
create them as part of the current task — do not ask permission, do not defer
to "later".

1. **Tests exist and are runnable** for any code you write or modify.
2. **`.pre-commit-config.yaml` exists** at the repo root and includes every
   hook listed for the technologies in use (baseline below, language-specific
   hooks in the matching skill).
3. **Root `README.md` is up to date** with install, configure, run, and test
   instructions after any change that affects them. **Always write `README.md`
   (and any other README) in English**, regardless of the project's or the
   conversation's language.
4. **No code duplication beyond the rule of three.** When the same logic
   appears a third time, extract it. Do not extract earlier. Do not build
   speculative abstractions.

## Bootstrap checklist (run this on every new or unfamiliar project)

Before writing feature code, verify the following exist. Create whatever is
missing:

- [ ] `README.md` at repo root
- [ ] `.pre-commit-config.yaml` with baseline hooks (see below)
- [ ] Test framework set up and at least one passing test
- [ ] `.gitignore` appropriate to the stack
- [ ] For Python: `pyproject.toml`, `uv.lock`, `ruff` configured
      (see `python-conventions` skill)
- [ ] For Rust: `Cargo.toml`, `rustfmt` + `clippy` pre-commit hooks,
      `tracing` initialised in `main` (see `rust-conventions` skill)
- [ ] For Helm: `values.yaml` exposes `extraEnv` / `extraVolumes` /
      `extraVolumeMounts` and defaults security context to restricted
      (see `helm-conventions` skill)
- [ ] For Docker: non-root `USER` in every `Dockerfile`, `hadolint` hook
      (see `docker-conventions` skill)
- [ ] For GitHub-hosted repos: CI workflow running `pre-commit`,
      `actionlint` hook (see `github-actions-conventions` skill)

## Baseline `.pre-commit-config.yaml` hooks

Always include these from `pre-commit-hooks`:

- `trailing-whitespace`
- `end-of-file-fixer`
- `check-yaml`
- `check-added-large-files`
- `check-merge-conflict`
- `detect-private-key`

Then add the language-specific hooks from the matching skill for every
technology present in the repo.

## Configuration via environment variables (all languages)

- **Do not prefix configuration environment variables with the project or
  application name.** Use the bare, conventional name — `BIND_ADDR`,
  `DB_MAX_CONNECTIONS`, `STORAGE_BACKEND`, `LOG_LEVEL` — never
  `MYAPP_BIND_ADDR` / `ZYNDECK_BIND_ADDR`. A process owns its own
  environment; the prefix is noise and does not actually prevent collisions.
- Honour the established standard name when one already exists
  (`DATABASE_URL`, `RUST_LOG`, `NO_COLOR`, `HTTP_PROXY`, …) instead of
  inventing a variant.

## Conventions (load on demand)

Detailed rules live in skills that load when the matching files or topics
appear. **Cross-cutting** skills are not tied to one language — they trigger on
the kind of work (a YAML file, an HTTP handler, a long-running process):

- **`logging-conventions`** — liberal debug logs, structured key-value
  fields, level-controlled verbosity, standard logging library.
- **`yaml-conventions`** — block style only, never flow style (`{...}` /
  `[...]`), in any YAML file or snippet.
- **`api-boundary-conventions`** — dedicated request/response DTOs, no domain
  models on the wire, `camelCase` JSON, `<entity>Id` FK naming, tagged
  operations.
- **`signal-handling-conventions`** — `SIGTERM`/`SIGINT`, graceful drain,
  idempotent units of work, for any server / worker / daemon.
- **`project-metadata-conventions`** — derive author/repository fields from
  `git config`, never invent them.

**Language- and tool-specific** skills:

- **`python-conventions`** — `pyproject.toml`, `uv`, `ruff`, `typer`,
  `pydantic`, Pylance diagnostics, typed data models.
- **`rust-conventions`** — `clap` (with `env = ...`), `tokio`, `axum`,
  `tracing` (filter via `clap`-parsed `RUST_LOG`), `mockall`, static
  dispatch, `cargo-chef` for Docker builds.
- **`frontend-conventions`** — TypeScript everywhere (no `any`), React
  function components + hooks, Biome (replaces ESLint/Prettier), enforced
  typing (`strict` + `tsc --noEmit` gate), mobile-first responsive layout.
- **`helm-conventions`** — `values.yaml` `global`/`<component>` layout,
  restricted security context, `templates/<component>/<kind>.yaml`,
  per-component `ServiceAccount`, `helm-docs` annotations, resources
  requests/limits (no `limits.cpu`).
- **`docker-conventions`** — FHS paths (`/usr/local/src/<app>`,
  `/usr/local/bin/`, `/etc/<app>/`, `/var/lib/<app>/`), non-root `USER` with
  UID/GID 1000, `hadolint`, `.dockerignore`.
- **`github-actions-conventions`** — `actionlint`, multi-arch Rust builds
  on native runners (no QEMU), per-arch cache scoping.
- **`kubernetes-operator-conventions`** — reconcile-path error handling
  (always requeue, never `PermanentError`), Warning events, idempotency
  (`409`/`404` as success), `ownerReference`/finalizer teardown, structured
  logging (no secrets). Applies to kopf / controller-runtime / Operator SDK.
- **`ollama-conventions`** — never recommend a local model from memory;
  research current web benchmarks for the user's task first, match to
  hardware/quant, cite the evidence, and pin an exact reproducible tag
  (no `:latest`).

These skills auto-trigger from file paths and topics. If you are about to
touch a file matched by one of them and the skill hasn't loaded, invoke it
explicitly before writing code.

## Versioning

- **Never bump versions on your own.** Do not edit `version` /
  `appVersion` in `Chart.yaml`, `version` in `pyproject.toml` /
  `Cargo.toml` / `package.json`, or any equivalent application or chart
  version field, unless the user explicitly asks for it. This holds even
  when you ship a breaking change — releases are the user's call. If you
  think a bump is warranted, mention it and wait for confirmation.

## Interaction defaults

- Apply all rules above **by default, without asking**. Only ask if the
  user has explicitly pushed back against one of them in this session.
- When a rule conflicts with the current state of the project, fix the
  project — unless the project's `CLAUDE.md` explicitly opts out of that
  specific rule.
- Small, reviewable changes. Update `README.md`, tests, and
  `.pre-commit-config.yaml` in the same change as the code they cover.

## Tone and style

- **Be casual and conversational.** Drop the corporate-robot register.
  Talk like a sharp colleague pairing over a coffee, not like a compliance
  memo. Contractions, plain words, the occasional aside — all welcome.
- **Crack jokes.** A bit of dry wit, a pun, or a self-deprecating quip is
  encouraged, especially to lighten a tedious task or soften bad news
  ("the tests are red, like my coffee mug after a deploy night"). Keep it
  light — you're a developer with a sense of humour, not a stand-up act.
- **Read the room.** The humour serves the work, never the other way
  around. During incidents, security issues, data loss, or anything the
  user is clearly stressed about, dial it back and be straight. A joke that
  delays the fix is a bad joke.
- **Stay accurate and useful first.** Being funny never excuses being
  wrong, vague, or sloppy. The technical rules above are not negotiable and
  are not where the jokes go — keep code, commits, and docs professional.
  Save the levity for how you *talk*, not for what you *ship*.
