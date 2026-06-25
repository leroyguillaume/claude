---
name: github-actions-conventions
description: GitHub Actions / CI conventions (canonical quality/build/chart/release
  workflows, SHA-pinned actions, OCI chart publish, multi-arch Rust builds on
  native runners, pragmatic caching).
  TRIGGER when: editing or creating any file under `.github/workflows/`,
  `.github/actions/`, `.github/release.yaml`, or a composite-action
  `action.yaml`/`action.yml`; setting up CI for a new repo on GitHub;
  configuring container/chart publishing or releases; user asks about GitHub
  Actions, runners, CI cache, or release automation in this repo.
  SKIP when: pure Python/Rust/Helm/Docker work with no workflow file touched and
  the user isn't asking about CI.
---

# GitHub Actions conventions

Apply these when the repo is hosted on GitHub.

## YAML style (workflows and `.github/` config)

- **No leading `---`** document marker at the top of workflow or other
  `.github/` config YAML files. Start directly with the first key.
- Write the trigger key as bare **`on:`**, never quoted `"on":`. (Modern
  parsers and `actionlint` handle the YAML truthiness of `on` fine.)
- Block style only, consistent with `yaml-conventions`.

## Step naming

- **Every step has a `name:`** — mandatory for `uses:` steps, and expected on
  `run:` steps too. A nameless action step reads as a bare SHA in the UI.
- Step names start with a **lowercase letter** (not sentence-cased): `name: set
  up the Rust toolchain`, not `name: Set up the Rust toolchain`. Proper nouns
  inside the name keep their capitals (`Rust`, `GHCR`, `GitHub`).
- Keep step names **static** — never interpolate a `${{ }}` expression into a
  `name:`. A conditional/templated label adds noise for no real benefit; pick
  one fixed name (`name: build the image`, not
  `name: build${{ inputs.push && ' and push' || '' }}`).

## Pin actions by SHA

- Pin **every** `uses:` to a full commit SHA, with a trailing comment naming
  the tag it corresponds to — and that comment must track the **latest**
  release tag of the action:
  ```yaml
  - uses: actions/checkout@<40-char-sha>  # v4.2.2
  ```
  A tag is mutable; a SHA is not. Resolve the SHA of the latest tag with
  `git ls-remote --tags https://github.com/<owner>/<repo> '<tag>^{}'`.
- Add **`.github/dependabot.yaml`** with the `github-actions` ecosystem so the
  pinned SHAs (and their tag comments) are bumped automatically.
- Never use a bare branch or tag ref (`@v4`, `@main`, `@stable`) in a
  committed workflow.

## The canonical workflow set

Create exactly these workflows, conditioned on what the repo contains. Give
each least-privilege `permissions:` (default `contents: read`; widen only in
the job that needs it).

- **`quality`** — always. Runs `pre-commit run --all-files` **and** the test
  suite, on push to the default branch and on every pull request. Because the
  `language: system` hooks shell out to real binaries, the job must install
  **every** tool the hooks need (toolchain + `helm`, `helm-docs`, `hadolint`,
  `actionlint`, …) before running `pre-commit`. This is the single quality
  gate — do not scatter fmt/lint/test across ad-hoc workflows.
- **`build`** — when a `Dockerfile` exists. Builds the image, and **pushes
  only when explicitly asked**: triggered by `workflow_dispatch` (a `push`
  boolean input) or invoked via `workflow_call` with `push: true`. On a plain
  push/PR it builds **without** pushing (validation only). Expose `push` and
  `version` as `workflow_call`/`workflow_dispatch` inputs. Multi-arch Rust:
  always a **static `matrix` over both architectures** — `amd64` on
  `ubuntu-24.04` and `arm64` on `ubuntu-24.04-arm` — each on its **own native
  runner**. Never QEMU-emulate a Rust build, and never drop an architecture
  from the matrix on PRs (validate both). When pushing, each arch job
  build/pushes **by digest** and a final `manifest` job assembles the
  multi-arch manifest (that job runs only when pushing). Derive image
  **tags and labels with `docker/metadata-action`** — labels on each per-arch
  build, tags in the `manifest` job (consumed from `DOCKER_METADATA_OUTPUT_JSON`
  by `docker buildx imagetools create`). Never hand-roll tag strings.
- **`chart`** — when a Helm chart exists. **Publishes** the chart as an **OCI
  artifact** to GHCR (`helm push` → `oci://ghcr.io/<owner>/charts`). The chart
  has its **own release lifecycle, decoupled from the app**: trigger it on a
  dedicated tag namespace **`chart-*`** (plus `workflow_dispatch` for manual
  publishes), never on PR (PR validation is `helm lint` inside `pre-commit`).
  Derive the chart version from the `chart-X.Y.Z` tag and pass it to
  `helm package --version <v>`; leave `appVersion` to `Chart.yaml` (the app
  image the chart targets evolves independently of the chart's own version).
  The `release` workflow does **not** publish the chart.
- **`release`** — always (the app-release orchestrator). Triggered by pushing a
  git tag `vX.Y.Z`. It: (1) derives the version from the tag (strip the leading
  `v` for a SemVer image tag); (2) calls **`build`** with `push: true` and the
  version; (3) creates a **GitHub Release** with auto-generated notes
  (`gh release create "$TAG" --generate-notes`). The version flows from the tag
  into the image tag **at build time** — never edit a `version`/`appVersion`
  field in a file to cut a release. **Release the chart separately** via its
  `chart-*` tag — the app and the chart version independently.
- **`.github/release.yaml`** — always, when a `release` workflow exists. The
  GitHub auto-generated-notes config (categorise PRs by label, exclude noise).
  `gh release create --generate-notes` reads it.

## Cache deliberately, and pragmatically

Cache what is expensive to **recompute**, not what is cheap to **re-download**.
The crates.io / registry download is fast; restoring a large dependency cache
can be **slower** than a clean fetch, and a stale cache is worse than none.

- **Keep**: the Docker layer cache, scoped **per architecture**
  (`type=gha,scope=<arch>`) so the two arch runners never clobber each other;
  and the compiled-dependency cache (`cargo-chef` in the `Dockerfile`,
  `Swatinem/rust-cache` for non-Docker Rust jobs) — these cache **CPU work**,
  not downloads.
- **Skip**: caches wrapped around a fast download just because you can. Measure
  before adding one.

**Never:**

- Never start a workflow file with `---`, and never quote `"on"`.
- Never use a bare branch/tag action ref — pin the SHA (with a tag comment) and
  let Dependabot bump it.
- Never push an image or publish a chart on a pull request; pushing happens only
  via `workflow_dispatch` or the `release` orchestration.
- Never cut a release by editing a version field — derive the version from the
  git tag at build time.
- Never QEMU-emulate a Rust multi-arch build when native runners exist, and
  never share one unscoped build cache across architectures.
- Never split the quality gate: `pre-commit` + tests live in the single
  `quality` workflow.
