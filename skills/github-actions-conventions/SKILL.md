---
name: github-actions-conventions
description: GitHub Actions / CI conventions (actionlint, multi-arch Rust builds
  on native runners, per-arch cache scoping).
  TRIGGER when: editing or creating any file under `.github/workflows/`,
  `.github/actions/`, or a composite-action `action.yaml`/`action.yml`; setting
  up CI for a new repo on GitHub; configuring multi-arch container builds; user
  asks about GitHub Actions, runners, or CI cache strategy in this repo.
  SKIP when: pure Python/Rust/Helm/Docker work with no workflow file touched and
  the user isn't asking about CI.
---

# GitHub Actions conventions

Apply these when the repo is hosted on GitHub.

**Always:**

- Use **GitHub Actions** for CI. At minimum: a workflow running `pre-commit`
  on every push to the default branch and every PR.
- Lint workflows with **`actionlint`** and add an `actionlint` pre-commit
  hook (local `language: system` hook calling the installed binary, matching
  the other tool hooks).
- For a **multi-arch container build of a Rust project**, build each
  architecture on its **own dedicated native runner** (e.g. `ubuntu-24.04`
  for `amd64` and `ubuntu-24.04-arm` for `arm64`), then assemble the
  multi-arch manifest by digest. Never cross-build Rust under QEMU
  emulation — it is pathologically slow for compiled languages.
- Manage build cache deliberately: scope the Docker layer cache **per
  architecture** (`type=gha,scope=<arch>`) so the two runners never clobber
  each other, and keep the Rust dependency cache warm (cargo-chef in the
  `Dockerfile`, `Swatinem/rust-cache` for non-Docker jobs).

**Never:**

- Never QEMU-emulate a Rust multi-arch build when native runners exist.
- Never share one unscoped build cache across architectures.
