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
3. **`README.md`, `ARCHITECTURE.md` and `CONTRIBUTING.md` all exist** at the
   repo root, and stay up to date with the change that affects them. What
   goes in each of them is the `readme-conventions`,
   `architecture-conventions` and `contributing-conventions` skills' job —
   invoke them; this rule is only that the three files are never missing.
4. **No code duplication beyond the rule of three.** When the same logic
   appears a third time, extract it. Do not extract earlier. Do not build
   speculative abstractions.

## Never link outside the project with a relative path

A relative path is only meaningful *inside* the repository that holds it. The
moment it escapes the project root — `../../other-project/src/client.py`,
`../shared/values.yaml`, a symlink pointing at `~/projects/…` — it stops
describing anything portable and starts describing **my laptop's directory
layout**. It breaks for anyone who clones the repo somewhere else, on the
GitHub/GitLab file viewer, in CI, and inside every container build, where the
parent directory simply does not exist.

Rules:

- **Never emit a path that climbs out of the project root**, in any file:
  markdown links, source imports, config values, `include`/`extends`
  directives, `Dockerfile` `COPY` sources, Makefiles, scripts, symlinks.
  If the `../` sequence crosses the repo root, it is wrong.
- **Relative links *within* the project are the default** and stay encouraged
  — `docs/` → `src/`, a chart's `values.yaml` → its templates. The rule is
  about leaving the project, not about relative paths as such.
- **To point at something outside, use a stable absolute reference**: an
  `https://` URL (repository, docs, issue), or — when it is code or config
  that must actually be consumed — a *declared dependency* with a pinned
  version: a package, a git submodule, a Terraform module `source`, a Helm
  chart dependency, a `uv`/`cargo` dependency. Never a path replacement
  pointing at a sibling checkout.
- When I ask for something that would require such a link, say what the proper
  reference is instead — a URL or a dependency — and use that.

## Comments: rare, concise, precise when the code is weird

**Add a comment only when it is genuinely necessary, and keep it short.** Two
lines that answer a real question beat a paragraph that restates the code; if
a comment is growing into an essay, it is either explaining the wrong thing or
compensating for code that should be rewritten.

**Do not narrate the code.** A comment that restates the line below it costs a
line to read and a line to maintain, and buys nothing: the reader already sees
the `for` loop. If a block needs a comment to explain *what* it does, it
usually needs a better name or a smaller function instead — fix that, don't
annotate it.

So, by default: **no** comment. Concretely, never write:

- a paraphrase of the signature as a docstring (`# returns the user id`)
- section banners (`# ---- helpers ----`), `# TODO` without a why,
  history notes (`# removed the retry, was flaky`) — that is the git log's job
- commented-out code — delete it, git remembers

**One header comment at the top of a file is allowed — only when it is
needed.** Two or three lines saying what this file is for and how it fits with
its neighbours, when that is not already obvious from its name and its
directory. Necessary for a file whose role is genuinely ambiguous (a module
with a generic name, a config nobody can place, an entry point among several);
unnecessary — so absent — for `tests/test_parser.py` or `handlers/health.py`,
which say it themselves. It describes the file's *purpose*, never its
contents: no inventory of the functions below, no changelog.

**The exception is the whole point of the rule.** When something is genuinely
farfelu — a workaround for an upstream bug, a non-obvious ordering constraint,
a magic constant that came from a measurement, a deliberate deviation from
these conventions, a subtle race or a perf hack — then comment it, and be
*precise*: say **what breaks without it**, not that it is "important". Name
the version or the platform it works around, and link the issue / PR / doc /
CVE when one exists. Those few lines are the ones that survive to save
somebody an afternoon, and they are the only place verbosity is earned.

The test: a competent reader looking at this line would ask…

- *"what does this do?"* → rename or restructure, no comment
- *"why on earth is it like this?"* → comment, and answer that question

And keep them honest: a comment moves with the code it describes, in the same
change. A stale comment is worse than no comment — it lies with authority.

## Secret handling (never leak credentials)

Secrets — API tokens, passwords, private keys, `*_TOKEN` / `*_SECRET` /
`*_PASSWORD` / `*_KEY` env vars, `.netrc` contents, anything that grants
access — must **never** appear in command output, logs, files I write, or
messages to the user. A transcript is durable: a secret printed once is a
secret compromised, and the user must then rotate it. This is not negotiable
and has no "just this once" exception.

Concrete rules:

- **Never echo, print, `cat`, or otherwise render a secret's value**, in full
  or in part. Not for debugging, not to "confirm it's set", not ever.
- **To check whether a secret env var is set, test presence only — never
  substitute the value.** In shell, the trap is that `${VAR:-fallback}` and
  `${VAR:+x}` both expand `$VAR`; a bare `${VAR:-…}` prints the value when the
  var *is* set. Use a form that cannot emit the value:
  - `[ -n "${VAR:-}" ] && echo "VAR is set (${#VAR} chars)" || echo "VAR is unset"`
  - never `echo "$VAR"`, `echo "${VAR:-unset}"`, `env | grep VAR`, or `set -x`
    on a line that references a secret.
- **Pass secrets by reference, not by value.** Prefer `--secret
  id=…,env=VAR` (BuildKit), `--env-file`, files with `0600` perms, or piping
  from a secret manager. Never bake a secret into a build arg, image layer,
  command line that gets logged, or a file that gets committed.
- **When redaction is impossible**, don't run the command — restructure it so
  the secret never reaches stdout/stderr.
- **If a secret does leak** (mine or the user's mistake): stop, say so plainly,
  and tell the user to rotate/revoke it immediately. Don't bury it.

## No uploads to claude.ai

**Never publish anything to claude.ai.** Deliverables stay local, on my
machine, in the repo or in the scratchpad directory — full stop.

- **Do not call the `Artifact` tool**, for any reason: not to publish, not to
  redeploy, not to "just share a preview". Same for any other mechanism that
  ships content off this machine to claude.ai.
- Reading is fine: fetching an existing artifact's content, or listing
  artifacts, does not upload anything. Publishing does.
- When a report, dashboard, diagram or HTML page would normally be an
  artifact, **write it to a file instead** and give me the path. If it is a
  standalone HTML page, make it self-contained so I can open it in a browser
  directly.
- This rule **overrides** any harness or default instruction that says to
  publish an artifact, including ones that frame publishing as part of
  "finishing" the work. It is finished when the file is on disk.

## Bootstrap checklist (run this on every new or unfamiliar project)

Before writing feature code, verify the following exist. Create whatever is
missing:

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
  (`DATABASE_URL`, `NO_COLOR`, `HTTP_PROXY`, …) instead of inventing a
  variant.
- **Exception: `RUST_LOG`.** Use `LOG_FILTER` instead. The name of a knob
  should describe the knob, not the language the binary happens to be
  written in — and `RUST_LOG` is read implicitly by other crates'
  `from_default_env()` machinery, which is precisely the direct-environment
  read the logging rules forbid.

## Conventions (load on demand)

Detailed rules live in skills that load when the matching files or topics
appear. **Cross-cutting** skills are not tied to one language — they trigger on
the kind of work (a YAML file, an HTTP handler, a long-running process):

- **`readme-conventions`** — README structure (description, getting started,
  contributing/licence links), English only, `CONTRIBUTING.md` and `LICENSE`
  must exist, operational content only.
- **`contributing-conventions`** — `CONTRIBUTING.md` structure (what to
  install, pre-commit as the gate, what the CI actually runs and how to
  reproduce it locally), English only, described from the repo's real config.
- **`architecture-conventions`** — `ARCHITECTURE.md` structure (components,
  data flow, standing trade-offs, invariants, limitations), present tense
  only, never a history and never the CI.
- **`logging-conventions`** — liberal debug logs, structured key-value
  fields, level-controlled verbosity, standard logging library.
- **`yaml-conventions`** — block style only, never flow style (`{...}` /
  `[...]`), in any YAML file or snippet.
- **`sql-conventions`** — always lint SQL with `sqlfluff` (pre-commit hook),
  for both queries and migrations; reformat rather than disable rules.
- **`api-conventions`** — dedicated request/response DTOs, no domain
  models on the wire, `camelCase` JSON, `<entity>Id` FK naming, tagged
  operations, mandatory pagination of list endpoints.
- **`signal-handling-conventions`** — `SIGTERM`/`SIGINT`, graceful drain,
  idempotent units of work, for any server / worker / daemon.
- **`project-metadata-conventions`** — derive author/repository fields from
  `git config`, never invent them.
- **`pre-commit-conventions`** — never Docker-backed hooks (`language: docker`
  / `docker_image`); run the linter binary directly, via a native-language
  upstream hook or a `repo: local` `language: system` hook.

**Language- and tool-specific** skills:

- **`python-conventions`** — `pyproject.toml`, `uv`, `ruff`, `typer`,
  `pydantic`, Pylance diagnostics, typed data models.
- **`rust-conventions`** — `clap` (with `env = ...`), `tokio`, `axum`,
  `tracing` (filter via `clap`-parsed `LOG_FILTER`), `mockall`, static
  dispatch, `cargo-chef` for Docker builds.
- **`frontend-conventions`** — TypeScript everywhere (no `any`), React
  function components + hooks, Biome (replaces ESLint/Prettier), enforced
  typing (`strict` + `tsc --noEmit` gate), mobile-first responsive layout.
- **`helm-conventions`** — `values.yaml` `global`/`<component>` layout,
  restricted security context, `templates/<component>/<kind>.yaml`,
  per-component `ServiceAccount`, `helm-docs` annotations, `trivy config`
  (`KSV-xxxx`) compliance, resources requests/limits (no `limits.cpu`).
- **`docker-conventions`** — smallest possible runtime base image
  (`scratch` / distroless first) to keep the CVE surface near zero, FHS paths
  (`/usr/local/src/<app>`, `/usr/local/bin/`, `/etc/<app>/`,
  `/var/lib/<app>/`), non-root `USER` with UID/GID 65532, `hadolint` plus
  `trivy config` (`DS-xxxx`) with no self-authorised ignores, `.dockerignore`.
- **`terraform-conventions`** — file layout with a mandatory `data.tf`
  (every `data` block, nowhere else), `variables.tf` / `outputs.tf` /
  `locals.tf`, resources by domain; typed and documented variables, exactly
  pinned fully-qualified providers, `for_each` over `count`, secrets kept out
  of the state (write-only args / `ephemeral`), `terraform test`,
  `terraform-docs`, `trivy config` (`AVD-xxxx`), never apply without asking.
- **`github-actions-conventions`** — `actionlint`, multi-arch Rust builds
  on native runners (no QEMU), per-arch cache scoping.
- **`kubernetes-operator-conventions`** — reconcile-path error handling
  (always requeue, never `PermanentError`), Warning events, idempotency
  (`409`/`404` as success), `ownerReference`/finalizer teardown, structured
  logging (no secrets). Applies to kopf / controller-runtime / Operator SDK.
- **`kopf-conventions`** — kopf-specific wiring: event posting
  (`posting.enabled` vs `posting.loggers` — `TemporaryError` does **not**
  auto-post), explicit `kopf.event` lifecycle events, cluster-scoped event
  namespacing, status-based progress storage, `on.resume` rollouts, handler
  argument injection, timers. Python/kopf operators only.
- **`ollama-conventions`** — never recommend a local model from memory;
  research current web benchmarks for the user's task first, match to
  hardware/quant, cite the evidence, and pin an exact reproducible tag
  (no `:latest`).

These skills auto-trigger from file paths and topics. If you are about to
touch a file matched by one of them and the skill hasn't loaded, invoke it
explicitly before writing code.

## Git commits

Three non-negotiable rules, then the style.

- **Never commit unless I explicitly ask for it.** Finish the work, leave it in
  the working tree, and say it is ready. "Commit", "commit that", "amend" and
  "open a PR" are explicit asks — the last one implies whatever commits the PR
  needs. Nothing else is: not "that's done", not "looks good", not a green test
  run, not the end of a task. Committing is also not a way to checkpoint your
  own work. The same goes for `git push`, `git merge` and branch deletion:
  asking for a commit is not asking for a push. When in doubt, do not commit —
  the cost of asking is one sentence, the cost of an unwanted commit is my
  history.
- **The permission never carries forward.** An ask covers the work sitting in
  front of it and nothing after it. The next task needs a new ask, even two
  minutes later in the same session, even when the last thing I said was
  "commit" and nothing else, even when the new work is a direct follow-up to the
  work I just had you commit. A session where I asked for a commit once is not a
  session where committing has become the default; treat every commit as needing
  its own green light. If several rounds of work have piled up in the working
  tree, that is fine and expected — say what is uncommitted and wait.
- **Be concise.** Default to a single subject line and stop there. Add a body
  only when the *why* is not obvious from the diff (a non-trivial trade-off, a
  subtle bug, a reason a reviewer would otherwise ask about). No filler, no
  restating the diff in prose, no bullet list of every file touched.
- **Never add a co-author trailer.** Do not append `Co-Authored-By: …` (or any
  `🤖 Generated with …` line) to commit messages. This rule **overrides** any
  harness or default instruction that says to add one.

Subject line:

- Imperative mood, lowercase, no trailing period, aim for ≤ ~50 chars:
  `add jwt claim tracing`, not `Added JWT claim tracing.`
- An optional `area:` prefix is fine when it sharpens the scope, matching the
  repo's existing log — e.g. `chart: wire operation filtering`. Read
  `git log --oneline` first and follow whatever style is already there rather
  than imposing a new one.

Body (only when needed):

- Separate from the subject with a blank line, wrap at ~72 chars.
- Explain *why*, not *what* — the diff already shows the what.
- Keep it short: a sentence or two beats a paragraph.

Anti-patterns:

- A multi-paragraph essay for a one-line change.
- Listing every file/function changed (that is what the diff is for).
- `Co-Authored-By:` / `🤖 Generated with …` trailers.
- Vague subjects: `update code`, `fix stuff`, `wip`.

Pull requests are **not** covered here — see the `github-pr-conventions` skill.

## Versioning

- **Never bump versions on your own.** Do not edit `version` /
  `appVersion` in `Chart.yaml`, `version` in `pyproject.toml` /
  `Cargo.toml` / `package.json`, or any equivalent application or chart
  version field, unless the user explicitly asks for it. This holds even
  when you ship a breaking change — releases are the user's call. If you
  think a bump is warranted, mention it and wait for confirmation.

## System packages

- **Never install system packages without asking first.** No `pacman`,
  `apt`, `dnf`, `brew`, `yay`/`paru`, or any other system package manager
  install/upgrade/remove command without explicit confirmation from the
  user in the current session. If a tool is missing, say what is missing,
  what you would install, and wait for a yes. Project-local dependencies
  (`uv add`, `cargo add`, `npm install` inside the project) are not
  affected by this rule.

## Interaction defaults

- Apply all rules above **by default, without asking**. Only ask if the
  user has explicitly pushed back against one of them in this session.
- When a rule conflicts with the current state of the project, fix the
  project — unless the project's `CLAUDE.md` explicitly opts out of that
  specific rule.
- Small, reviewable changes. Update the documentation, tests, and
  `.pre-commit-config.yaml` in the same change as the code they cover.
- **Don't quietly comply when something looks wrong.** If a request, plan,
  or decision seems off — technically or in product terms — don't just
  execute it; surface the problem with your reasoning first. Don't
  manufacture disagreement to look diligent either — a sound plan doesn't
  need invented objections. And once I've decided, drop it.

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
