---
name: pre-commit-conventions
description: >-
  pre-commit configuration and hook choice.
  TRIGGER when: creating or editing `.pre-commit-config.yaml`; adding,
  replacing or bumping a hook; a hook only ships a `docker` variant; setting
  up linting for a repo with YAML (`.yamllint.yaml`); wiring a test suite (`pytest`, `cargo
  test`, …) into a commit gate; user asks why a hook is slow or needs Docker.
  SKIP when: not touching pre-commit configuration.
---

# pre-commit conventions

## Baseline hooks

**Every repo gets these from `pre-commit/pre-commit-hooks`**, whatever its
stack:

```yaml
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: <latest tag SHA>  # <latest tag>
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        args:
          - --allow-multiple-documents
        exclude: ^charts/[^/]+/templates/
      - id: check-added-large-files
        exclude: ^(.*/)?(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lock|uv\.lock|Cargo\.lock|poetry\.lock)$
      - id: check-merge-conflict
      - id: detect-private-key
```

The `exclude` on `check-added-large-files` keeps lockfiles out of the size
check: they are legitimately large and must stay versioned, and widening
`--maxkb` for everything would be worse. Keep only the patterns of the
lockfiles the repo has (`bun.lockb` for Bun < 1.2).

On top of them: the `yamllint` and `commit-msg` hooks below, and the hooks the
matching skill lists for every technology present in the repo.

## Never use Docker-backed hooks

**No hook may use `language: docker` or `language: docker_image`.** Docker
hooks pull an image, need a running daemon, break on machines/CI runners
without Docker, are slow on macOS, and mangle file paths through bind mounts.

Always run the tool directly. In order of preference:

1. **An upstream hook with a native language** (`python`, `golang`, `rust`,
   `node`, `system`, …). Many repos publish both variants under different ids —
   pick the non-Docker one.
2. **A `repo: local` hook with `language: system`**, calling the binary from
   `PATH`.

One deliberate exception to that order: **Biome runs as a local `system` hook**
(`frontend-conventions`). The upstream `biomejs/pre-commit` hook installs its
own Biome through `additional_dependencies`, a second version to keep in step
with the one in the lockfile.

### Known repos that ship both variants

| Tool | ❌ Docker id | ✅ Use instead |
| --- | --- | --- |
| hadolint (`hadolint/hadolint`) | `hadolint-docker` | `hadolint` (`language: system`) |
| shellcheck (`koalaman/shellcheck-precommit`) | `shellcheck` — **Docker only**, whole repo unusable | `shellcheck-py/shellcheck-py` |

### Canonical shellcheck hook

`koalaman/shellcheck-precommit` exposes *only* a `docker_image` hook, so drop
the repo entirely and use `shellcheck-py`, a pip wheel bundling the binary:
native, nothing to preinstall, and the version is pinned in the config.

```yaml
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: <latest tag SHA>  # <latest tag>
    hooks:
      - id: shellcheck
```

A local `language: system` hook calling a `shellcheck` from `PATH` is the
fallback for a runner that cannot install the wheel; the binary is then a
prerequisite (`contributing-conventions`) and CI installs it before
`pre-commit`.

## Always include yamllint

**Every repo containing YAML gets a `yamllint` hook**, alongside a
`.yamllint.yaml` at the root. `check-yaml` only proves a file parses; it says
nothing about how it is written, which leaves `yaml-conventions` resting on
whoever happens to be reviewing.

```yaml
  - repo: https://github.com/adrienverge/yamllint
    rev: <latest tag SHA>  # <latest tag>
    hooks:
      - id: yamllint
        # Warning-level rules (document-start among them) are printed and then
        # ignored without this — the hook passes anyway.
        args:
          - --strict
        # A Helm template is Go templating, not YAML, until it is rendered.
        exclude: ^charts/[^/]+/templates/
```

The hook is `language: python` upstream, so no Docker and nothing to
preinstall. Start from `extends: default` and state only the deviations — most
repos already satisfy the default ruleset, and dropping it to enable two rules
throws away `indentation`, `key-duplicates` and `document-start` for nothing:

```yaml
extends: default

rules:
  # yaml-conventions: no `---` opening a file. Add a per-rule `ignore:` for any
  # genuinely multi-document file — the separators between documents are
  # required syntax and the rule cannot tell them from a stylistic opener.
  document-start:
    present: false
  # yaml-conventions: block style only. `non-empty` still allows `{}` / `[]`.
  braces:
    forbid: non-empty
  brackets:
    forbid: non-empty
  # Disable rather than tune: a digest-pinned image reference alone is ~150
  # characters, and a helm-docs annotation is one line per key by construction.
  line-length: disable
  # A GitHub workflow's trigger key is a bare `on:`, which YAML 1.1 reads as a
  # boolean: checking keys fails every workflow. Values are still checked.
  truthy:
    allowed-values:
      - 'true'
      - 'false'
    check-keys: false
  # The default of 2 rejects `uses: org/action@<sha> # v4.2.0`, the
  # single-space pin comment most tools and hand edits produce.
  comments:
    min-spaces-from-content: 1
```

Three traps worth knowing:

- **Without `--strict`, yamllint exits 0 on warnings.** `document-start` is a
  warning by default, so the finding is printed and the hook goes green.
- **`--strict` turns the default ruleset's warnings into failures**, so
  `truthy` (keys checked) and `comments` (two spaces before an inline comment)
  fail GitHub workflows unless they are tuned as above.
- **A rule that fires on a file it cannot be satisfied on** (`document-start`
  on a multi-document manifest) needs a per-rule `ignore:`, not a global one —
  a top-level `ignore:` drops the file from *every* rule.

## Always reject co-authors in commit messages

**Every repo gets a `commit-msg` hook that fails on any `Co-Authored-By:`
trailer or any `Generated with …` line**, whoever or whatever they name. A
commit has one author; a line that slips through lands in a client's history
for good. The hook makes the rule mechanical instead of a matter of attention.

```yaml
default_install_hook_types:
  - pre-commit
  - commit-msg

repos:
  - repo: local
    hooks:
      - id: no-co-authors
        name: no co-authors in commit message
        entry: '^\s*co-authored-by:|\bgenerated with\b'
        language: pygrep
        args:
          - --ignore-case
        stages:
          - commit-msg
```

Traps:

- **`default_install_hook_types` is mandatory.** A plain `pre-commit install`
  only installs the `pre-commit` hook type; without this key the
  `commit-msg` hook is declared and never runs. In a repo that already had
  pre-commit installed, re-run `pre-commit install` once.
- **`\b` in front of `generated` is deliberate**: without it, a legitimate
  `docs regenerated with helm-docs` would be rejected.
- **Never use `--no-verify` to get a commit through this hook.** A failure
  means the message is wrong: rewrite it.
- `pre-commit run --all-files` (and so CI) skips `commit-msg` hooks — the
  hook guards local commits only.

## Never run tests from a hook

**No hook runs a test suite.** Not `cargo test`, not `pytest`, not `vitest`,
not `go test`, not `npm test` — whatever the language, whatever the id it is
given. `pre-commit` is a *lint* gate: fast, deterministic, file-scoped checks
that a developer can afford on every single commit.

A test suite is none of those things:

- **It is slow, and it only gets slower.** A gate that costs thirty seconds is
  a gate people start bypassing with `--no-verify` — and a gate that gets
  bypassed protects nothing, including the linters that were fine.
- **It is not file-scoped.** Every test hook ends up `pass_filenames: false`,
  so a one-word README fix pays for the whole suite.
- **It needs an environment the hook cannot promise** — a database, a fixture
  server, a built front end, network access. When that environment is missing
  locally the hook fails on code that is perfectly good.
- **CI already runs it, and runs it better** — on a clean checkout, in
  parallel, with the services it needs.

So: **the test suite belongs in CI**, in the `quality` workflow next to
`pre-commit run --all-files` (see `ci-conventions`), as its own
job. Not in `.pre-commit-config.yaml`.

If a repo already has a test hook, **remove it and add the CI job in the same
change** — dropping the hook without wiring the suite into CI is how a suite
stops being run at all.

Type checking is **not** a test: `tsc --noEmit`, `mypy` and `clippy` are static
analysis, they stay in pre-commit.

## Other rules

- **Pin every `rev` to a full commit SHA, with the tag as a comment**; never
  `master`/`main`, never a bare tag: a tag can be moved, and hooks run in CI
  (`ci-conventions`). `pre-commit autoupdate --freeze` writes exactly that, and
  Dependabot's `pre-commit` ecosystem bumps the SHA and the comment together
  (`dependency-update-conventions`).
- **A `rev`, image tag or tool version written into a file is resolved when you
  write it, never from memory.** Look up the upstream's latest release
  (`gh release view -R <owner>/<repo> --json tagName`, or the registry) and
  write that; then take the commit it points to for a `rev`
  (`gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`). Snippets in skills
  show a placeholder (`<latest tag>`) for that reason.
- **Local hooks always set `language: system`** plus either `types:`/`files:`
  or `pass_filenames: false` — an unfiltered local hook runs on every file in
  the repo. The exception is a pure regex check, which uses `language:
  pygrep`; a `commit-msg`-only hook needs no filter, it is only ever handed
  the message file.
- **YAML block style only** in `.pre-commit-config.yaml`: write `types:` /
  `args:` as a list of `-` items, never `[shell]` / `[--fix]`. See
  `yaml-conventions`.
- Group all `repo: local` hooks under a **single** `- repo: local` entry.
