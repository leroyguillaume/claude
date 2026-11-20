---
name: mise-conventions
description: >-
  mise: every dev tool and toolchain version in `mise.toml`, the lockfile,
  the dev environment, installing tools in CI.
  TRIGGER when: creating or editing `mise.toml`, `.mise.toml` or `mise.lock`;
  a `rust-toolchain.toml`, `.python-version`, `.nvmrc`, `.node-version` or
  `.tool-versions` (they move into `mise.toml`); scaffolding a project;
  adding a tool or toolchain a contributor or CI must install; a CI step
  installing one (`setup-node`, `setup-python`, rustup); user asks about
  mise or pinning dev tools.
  SKIP when: the app's runtime dependencies (`pyproject.toml`, `Cargo.toml`,
  `package.json`); the commands contributors run (`task-conventions`).
---

# mise conventions

`mise.toml` says *which tools, at which version*, toolchains included, and the
development environment. `mise install` from a fresh clone gives a
contributor and CI the same binaries; mise is the only thing either installs
by hand.

It holds no `[tasks]`: the commands contributors and CI run live in
`Taskfile.yml` (`task-conventions`), so a version bump lands here and nowhere
else, and a command changes there and nowhere else.

`mise.toml` goes in every repository a contributor builds or checks, as part
of the bootstrap.

## `mise.toml`

At the repository root, named `mise.toml` (not `.mise.toml`, not
`.tool-versions`, which carries neither backends nor settings nor a lock),
and committed.

```toml
min_version = "<mise version this file needs>"

[tools]
task = "<latest>"
pre-commit = "<latest>"
helm = "<latest>"

[settings]
lockfile = true
disable_backends = ["asdf", "vfox"]
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

### mise pins everything

`mise.toml` is the only file that holds a dev tool's version, toolchains
included. A `rust-toolchain.toml`, `.python-version`, `.nvmrc`,
`.node-version`, `.terraform-version` or `.tool-versions` found in the repo
moves into `mise.toml` and is deleted in the same change: two pins drift, and
the dependency bot bumps one of them.

```toml
[tools]
rust = { version = "<latest>", components = ["rustfmt", "clippy"], profile = "minimal" }
python = "<latest>"
uv = "<latest>"
node = "<latest>"

[env]
UV_PYTHON = { value = "{{ tools.python.path }}", tools = true }
```

- **Rust**: mise installs rustup when it is missing and sets
  `RUSTUP_TOOLCHAIN`, which rustup ranks above any `rust-toolchain.toml`.
  `components` and `profile` carry what the `[toolchain]` table did. The pin
  is still not the MSRV (`rust-build-conventions`).
- **Python**: mise installs the interpreter, uv the dependencies
  (`python-conventions`). `UV_PYTHON` points uv at mise's interpreter;
  without it uv can pick a Python it downloaded itself.
- **Node.js**: a `docs/` site or a front end uses the root `node`; no
  `.nvmrc` beside it.
- **Container images are the one pin outside mise.** A `Dockerfile` builds
  from its `FROM` tag (`rust:<version>`, `python:<version>`), which mise does
  not read: keep that tag on the version `mise.toml` pins, and bump both in
  the same PR.

### `mise.lock`

`lockfile = true` keeps `mise.lock` beside `mise.toml`: exact versions,
download URLs and checksums per platform. Commit it. CI installs with
`mise install --locked`, which refuses anything the lock does not record.
A new lockfile covers the common platforms; when one is missing, add it with
`mise lock --platform linux-x64,macos-arm64`. `mise.local.lock` is never
committed.

### `[env]`

Only non-secret development defaults: a log level, a local URL, `_.path` for
a `bin/` of project scripts. mise is the one thing that loads the
environment, never a task runner beside it (`task-conventions`), so a task, a
bare `pytest` and the IDE see the same variables.

Secrets never go in `mise.toml`. They come from `mise.local.toml` or a `.env`
loaded with `_.file = ".env"`, both gitignored, with a committed
`.env.example` holding the names only.

### Trust

mise refuses to load a project's `[env]` and settings until the config is
trusted. A contributor runs `mise trust` once after cloning; CI trusts
configs on its own (`CI` is set). Never set `trusted_config_paths` to a
parent directory of all checkouts to make the prompt go away.

## `.gitignore`

```gitignore
mise.local.toml
mise.local.lock
.env
```

## pre-commit

Add to `.pre-commit-config.yaml` (`pre-commit-conventions`):

```yaml
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

Every job that needs a tool installs it with mise: never `setup-node`,
`setup-python`, a rustup action, `setup-task` or an `apt-get install` of a
dev tool beside it, which is a second pin of the same version. What the job
runs next is `task-conventions`' rule.

GitHub Actions, SHA-pinned (`github-actions-conventions`):

```yaml
      - name: install the tools
        uses: jdx/mise-action@<latest tag SHA> # <latest tag>
        with:
          cache: false
      - name: lint
        run: task lint
```

With `mise.lock` committed, the action installs with `--locked`. `cache:
false` because the tools are downloads (`ci-conventions`); turn it on only
when an install builds from source (`cargo:`, `go:`), and never in a job that
publishes.

GitLab CI, on the official image pinned to an exact version
(`gitlab-ci-conventions`); tools run through `mise exec`:

```yaml
quality:
  image: ghcr.io/jdx/mise:<mise version>-debian
  script:
    - mise install --locked
    - mise exec -- task lint
```

## Dependency updates

Renovate's `mise` manager bumps `mise.toml` and `mise.lock` together,
toolchains included (`dependency-update-conventions`). It is on by default;
a config with an `enabledManagers` list has to name it.

## CONTRIBUTING

The setup starts with installing mise (link its install page), then `mise
trust` and `mise install`; the tooling list is a link to `mise.toml`, not a
copy of it (`contributing-conventions`).
