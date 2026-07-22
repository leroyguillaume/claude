---
name: pre-commit-conventions
description: pre-commit conventions — never use Docker-backed hooks, always run
  the linter binary directly (`language: system` / native pre-commit language).
  TRIGGER when: creating or editing `.pre-commit-config.yaml`; adding, replacing
  or bumping a pre-commit hook; a hook repo only ships a `docker` /
  `docker_image` variant; user asks why a hook is slow, why it needs Docker, or
  how to run a linter in pre-commit.
  SKIP when: not touching pre-commit configuration.
---

# pre-commit conventions

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

### Known repos that ship both variants

| Tool | ❌ Docker id | ✅ Use instead |
| --- | --- | --- |
| hadolint (`hadolint/hadolint`) | `hadolint-docker` | `hadolint` (`language: system`) |
| shellcheck (`koalaman/shellcheck-precommit`) | `shellcheck` — **Docker only**, whole repo unusable | local `system` hook, or `shellcheck-py/shellcheck-py` |

### Canonical shellcheck hook

`koalaman/shellcheck-precommit` exposes *only* a `docker_image` hook, so drop
the repo entirely and declare a local one:

```yaml
  - repo: local
    hooks:
      - id: shellcheck
        name: shellcheck
        entry: shellcheck
        language: system
        types:
          - shell
```

`shellcheck` then comes from the system package manager (`brew install
shellcheck`, `pacman -S shellcheck`, `apt install shellcheck`). Document that
prerequisite in the repo `README.md` and install it in CI before running
`pre-commit`.

If a runner genuinely cannot have the binary preinstalled, use
`shellcheck-py/shellcheck-py` (pinned, e.g. `rev: v0.11.0.1`) — it is a pip
wheel bundling the binary, still no Docker.

## Other rules

- **Pin every `rev`** to a tag; never `master`/`main`.
- **Local hooks always set `language: system`** plus either `types:`/`files:`
  or `pass_filenames: false` — an unfiltered local hook runs on every file in
  the repo.
- **YAML block style only** in `.pre-commit-config.yaml`: write `types:` /
  `args:` as a list of `-` items, never `[shell]` / `[--fix]`. See
  `yaml-conventions`.
- Group all `repo: local` hooks under a **single** `- repo: local` entry.
