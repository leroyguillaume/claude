---
name: task-conventions
description: >-
  Task (`Taskfile.yml`): the commands contributors and CI run.
  TRIGGER when: creating or editing `Taskfile.yml`/`.yaml` or an included
  Taskfile; scaffolding a project; adding a command contributors run (setup,
  lint, test, build, release); a CI step running one; a `Makefile` or
  `justfile` used as a task runner; user asks about Task or a task runner.
  SKIP when: pinning or installing tools (`mise-conventions`).
---

# Task conventions

`Taskfile.yml` says *what you run*: `task setup`, `task lint`, `task test`.
CI calls the same tasks, so "reproduce locally" is always the command the
pipeline ran.

It installs no tool: Task and everything the tasks call are pinned in
`mise.toml` (`mise-conventions`).

`Taskfile.yml` goes in every repository a contributor builds or checks, as
part of the bootstrap. A repository with a working `Makefile` or `justfile`
keeps it until the migration is asked for, and the migration replaces it in
the same change: never two task runners side by side.

## The file

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
  then `build`, `run`, `docs` when the project has them, and `release` around
  `scripts/release.sh` (`release-script-conventions`). A bare `task` lists
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
- **Never a secret** in the Taskfile, literal or default value, and no
  `dotenv:`: mise loads the environment (`mise-conventions`).
- **Never `prompt:` to guard something irreversible**: `task --yes` answers
  every prompt. The confirmation lives in the script the task calls.
- Task runs `cmds` through its own embedded POSIX shell interpreter on every
  OS, Windows included. Keep commands to what that shell and the listed tools
  provide; a step that needs `bash` or `pwsh` calls it explicitly, restricted
  with `platforms`.

## `.gitignore`

```gitignore
.task/
```

It holds Task's checksums for `sources`.

## pre-commit

Add to `.pre-commit-config.yaml` (`pre-commit-conventions`):

```yaml
  - repo: https://github.com/python-jsonschema/check-jsonschema
    rev: <latest tag SHA>  # frozen: <latest tag>
    hooks:
      - id: check-taskfile
```

## CI

**When `Taskfile.yml` exists, CI calls its tasks**, never the commands behind
them: `task lint`, not `pre-commit run --all-files`. A command changed in the
Taskfile then changes in CI too. Without a Taskfile, CI runs the commands
themselves. The tools, Task included, come from mise (`mise-conventions`).

## CONTRIBUTING

The setup ends with `task setup`; the tests and CI sections give `task test`
and `task lint`, and `task --list` for the rest (`contributing-conventions`).
