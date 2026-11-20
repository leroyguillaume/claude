---
name: mise-task-conventions
description: >-
  Dev tooling with mise (tool versions, dev env) and Task (`Taskfile.yml`
  entry points).
  TRIGGER when: creating or editing `mise.toml`, `.mise.toml`, `mise.lock`,
  `.tool-versions` or `Taskfile.yml`/`.yaml`; scaffolding a project; adding a
  tool a contributor or CI must install; adding a command contributors run
  (setup, lint, test, build); a `Makefile` or `justfile` used as a task
  runner; user asks about mise, Task, pinning dev tools or a task runner.
  SKIP when: the app's runtime dependencies (`pyproject.toml`, `Cargo.toml`,
  `package.json`); a version owned by its ecosystem file
  (`rust-toolchain.toml`, `.python-version`) with no mise file involved.
---

# mise and Task conventions

Two files, one job each:

- **`mise.toml`** says *which tools, at which version*, and the development
  environment. `mise install` from a fresh clone gives a contributor and CI
  the same binaries.
- **`Taskfile.yml`** says *what you run*: `task setup`, `task lint`,
  `task test`. CI calls the same tasks, so "reproduce locally" is always the
  command the pipeline ran.

Never cross the line: no `[tasks]` in `mise.toml`, and no tool installation in
the Taskfile. Commands in the Taskfile still work for someone who installed
Task another way; versions in `mise.toml` stay the only place a bump lands.

Both files go in every repository a contributor builds or checks, as part of
the bootstrap. A repository with a working `Makefile` or `justfile` keeps it
until the migration is asked for, and the migration replaces it in the same
change: never two task runners side by side.

## `mise.toml`

At the repository root, named `mise.toml` (not `.mise.toml`, not
`.tool-versions`, which carries neither backends nor settings nor a lock),
and committed.

```toml
min_version = "<mise version this file needs>"

[tools]
task = "<latest>"
pre-commit = "<latest>"
uv = "<latest>"
helm = "<latest>"

[settings]
lockfile = true
disable_backends = ["asdf", "vfox"]
idiomatic_version_file_enable_tools = ["node"]
```

- **Exact versions, resolved when written.** `"3.54.0"`, never `"3"` or
  `"latest"`: a fuzzy version moves under people's feet and makes the bump
  invisible in review. Look the version up (`mise latest <tool>`,
  `gh release view`), never from memory.
- **Registry short names** (`task`, `helm`, `uv`): the registry maps each to a
  backend that verifies what it downloads (aqua, `github:`). Write a backend
  explicitly only for a tool the registry lacks, and then `aqua:` or
  `github:<owner>/<repo>`. `ubi:` is deprecated: migrate it to `github:`.
- **`disable_backends = ["asdf", "vfox"]`.** Those plugins are shell scripts
  fetched from a third-party repository and run on install; the registry
  falls back to them for some tools, and this turns the fallback into an error
  instead of a silent plugin run.
- **`min_version`** set to the mise release the file was written with, so an
  older mise fails with a clear message rather than misreading the file.
- **Every tool a hook, a test or a task shells out to** is listed: the
  `language: system` hooks (`pre-commit-conventions`), `helm`, `terraform`,
  `hadolint`, `trivy`, `jq`. A binary that is not here is a prerequisite
  someone discovers as a cryptic failure.
- After editing `[tools]`, run `mise fmt` then `mise lock`.

### One pin per tool

A version an ecosystem file already pins stays there; `mise.toml` never
re-pins it, or the two drift and the dependency bot bumps only one.

| Tool | Pinned by | In `mise.toml` |
| --- | --- | --- |
| Rust | `rust-toolchain.toml` (`rust-build-conventions`), read by rustup | nothing: rustup stays the installer |
| Python | `.python-version`, read by uv (`python-conventions`) | `uv` only, never `python` |
| Node.js | `.nvmrc` (what `setup-node` reads) | `idiomatic_version_file_enable_tools = ["node"]`, no `node` key |

Idiomatic version files are off by default since mise 2025.10; the setting
above is what makes mise read `.nvmrc`.

### `mise.lock`

`lockfile = true` keeps `mise.lock` beside `mise.toml`: exact versions,
download URLs and checksums per platform. Commit it. CI installs with
`mise install --locked`, which refuses anything the lock does not record.
A new lockfile covers the common platforms; when one is missing, add it with
`mise lock --platform linux-x64,macos-arm64`. `mise.local.lock` is never
committed.

### `[env]`

Only non-secret development defaults: a log level, a local URL, `_.path` for
a `bin/` of project scripts. The environment is loaded by mise, never also by
the Taskfile (`dotenv:`), so `task test`, a bare `pytest` and the IDE see the
same variables.

Secrets never go in `mise.toml`. They come from `mise.local.toml` or a `.env`
loaded with `_.file = ".env"`, both gitignored, with a committed
`.env.example` holding the names only.

### Trust

mise refuses to load a project's `[env]` and settings until the config is
trusted. A contributor runs `mise trust` once after cloning; CI trusts
configs on its own (`CI` is set). Never set `trusted_config_paths` to a
parent directory of all checkouts to make the prompt go away.

## `Taskfile.yml`

At the repository root, named `Taskfile.yml`.

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: '3'

set:
  - errexit
  - nounset
  - pipefail

tasks:
  default:
    cmds:
      - task --list
    silent: true

  setup:
    desc: Install the project dependencies and the git hooks
    cmds:
      - uv sync --all-extras
      - pre-commit install

  lint:
    desc: Run every pre-commit hook on the whole repository
    cmds:
      - pre-commit run --all-files

  test:
    desc: Run the test suite
    cmds:
      - uv run pytest {{.CLI_ARGS}}
```

- **The standard names**: `setup` (project dependencies and `pre-commit
  install`, never the tools, which are `mise install`'s), `lint` (exactly
  `pre-commit run --all-files`, the gate CI runs), `test` (the whole suite),
  then `build`, `run`, `docs` when the project has them. A bare `task` lists
  them. Namespaces with `:` (`docs:build`) through `includes` when a
  component has a Taskfile of its own.
- **Every public task has a `desc`**, one line, imperative: `task --list`
  only shows those. A helper that is not an entry point is `internal: true`.
- **Thin tasks.** A task is the command a contributor would type, one to
  three lines. Logic that needs a loop or a condition goes in a script under
  `scripts/`, which the task calls: YAML is a poor place to read or debug
  shell, and the script keeps its `shellcheck` hook.
- **`{{.CLI_ARGS}}`** on `test` and the like, so `task test -- -k parser`
  narrows the run without a second task.
- **`set: [errexit, nounset, pipefail]`** at the top: without `pipefail`, a
  failing command piped into another reports success.
- **`deps` run in parallel.** Use them for independent prerequisites; for a
  sequence, list the steps in `cmds` (`- task: build`).
- **`sources` / `generates` only on expensive steps** (a build, a code
  generation), so they are skipped when nothing changed. A lint or a test
  never: they must run every time.
- **`requires: vars:`** for an input a task cannot run without, and
  **`preconditions`** with a `msg` for a state it needs (a running cluster, a
  file present), so the failure says what to do.
- **Never a secret** in the Taskfile, literal or default value.
- Task runs `cmds` through its own embedded POSIX shell interpreter on every
  OS, Windows included. Keep commands to what that shell and the listed tools
  provide; a step that needs `bash` or `pwsh` calls it explicitly, restricted
  with `platforms`.

## `.gitignore`

```gitignore
.task/
mise.local.toml
mise.local.lock
.env
```

`.task/` holds Task's checksums for `sources`.

## pre-commit

Add to `.pre-commit-config.yaml` (`pre-commit-conventions`):

```yaml
  - repo: https://github.com/python-jsonschema/check-jsonschema
    rev: <latest tag SHA>  # frozen: <latest tag>
    hooks:
      - id: check-taskfile

  - repo: local
    hooks:
      - id: mise-fmt
        name: mise fmt
        entry: mise fmt
        language: system
        files: ^mise\.toml$
        pass_filenames: false
```

`mise` itself is then a prerequisite: it is the one tool `mise.toml` cannot
install.

## CI

The `quality` job (`ci-conventions`) installs the tools with mise, then runs
the same tasks a contributor runs. Never a second, hand-maintained list of
`setup-*` actions or `apt-get install` lines.

GitHub Actions, SHA-pinned (`github-actions-conventions`):

```yaml
      - name: install the tools
        uses: jdx/mise-action@<latest tag SHA> # <latest tag>
        with:
          cache: false
      - name: lint
        run: task lint
      - name: test
        run: task test
```

With `mise.lock` committed, the action installs with `--locked`. `cache:
false` because the tools are downloads (`ci-conventions`); turn it on only
when an install builds from source (`cargo:`, `go:`), and never in a job that
publishes.

GitLab CI, on the official image pinned to an exact version
(`gitlab-ci-conventions`):

```yaml
quality:
  image: ghcr.io/jdx/mise:<mise version>-debian
  script:
    - mise install --locked
    - mise exec -- task lint
    - mise exec -- task test
```

## Dependency updates

Dependabot has no `mise` ecosystem, so `mise.toml` and `mise.lock` are
Renovate's, through its `mise` manager, which bumps both
(`dependency-update-conventions`). On GitHub, list `mise` in Renovate's
`enabledManagers` beside whatever Renovate already owns.

## CONTRIBUTING

The development setup (`contributing-conventions`) becomes: install mise
(link its install page), then

```bash
mise trust
```

```bash
mise install
```

```bash
task setup
```

The tooling list is a link to `mise.toml`, not a copy of it. The tests and CI
sections give `task test` and `task lint` as the commands, and `task --list`
as where to find the others.
