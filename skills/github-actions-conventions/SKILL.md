---
name: github-actions-conventions
description: GitHub Actions / CI conventions (canonical
  quality/build/security/chart/release workflows, mandatory Trivy scanning
  with SARIF upload, SHA-pinned actions, OCI chart publish, multi-arch Rust
  builds on native runners, pragmatic caching).
  TRIGGER when: editing or creating any file under `.github/workflows/`,
  `.github/actions/`, `.github/release.yaml`, or a composite-action
  `action.yaml`/`action.yml`; setting up CI for a new repo on GitHub;
  configuring container/chart publishing or releases; wiring vulnerability or
  image scanning into CI; user asks about GitHub Actions, runners, CI cache,
  Trivy/CVE scanning, or release automation in this repo.
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
  pinned SHAs (and their tag comments) are bumped automatically. The rest of
  that file, and where Renovate fits beside it, is `renovate-conventions`.
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
- **`security`** — always. The Trivy vulnerability scans (see below): `trivy
  fs` on the repo, and `trivy image` on the published image when the repo
  builds one. Runs on every pull request, on push to the default branch, and
  **on a `schedule`** — a nightly or weekly re-scan is the whole point, since
  CVEs are disclosed against code that hasn't changed. Uploads SARIF to GitHub
  code scanning, so it needs `security-events: write` in that job and nowhere
  else.
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

## Trivy — always, and not only as a gate

**Every repo runs Trivy in CI.** `trivy config` already runs in `pre-commit`
(the `DS-xxxx` / `KSV-xxxx` / `AVD-xxxx` misconfiguration checks — see
`docker-conventions`, `helm-conventions`, `terraform-conventions`); CI is
where the *vulnerability* side lives, because that one needs a database that
changes every day and a network to fetch it.

That difference is the reason the CI scan cannot be replaced by a hook: a
misconfiguration finding is deterministic and belongs at commit time, while a
CVE appears against code nobody touched. **A repo that only scans on PR is
scanning the day it merged, not today** — hence the `schedule`.

What to run:

- **`trivy image`** on the image the `build` workflow just produced — **before
  it is pushed**, in the same job, on PRs too. Publishing a known-vulnerable
  image and scanning it afterwards is the wrong order.
- **`trivy fs`** on the checkout, for the dependency lockfiles (`Cargo.lock`,
  `uv.lock`, `package-lock.json`) and any secret hits. This is what catches a
  vulnerable transitive dependency the manifest never mentions.

How to run it:

- **Fail the build on `HIGH` and `CRITICAL`** (`exit-code: 1`,
  `severity: HIGH,CRITICAL`). Lower severities are reported, not blocking.
- **`ignore-unfixed: true` on the blocking gate only.** A CVE with no upstream
  fix cannot be actioned by the contributor in front of it; blocking on it
  just teaches everyone that the red X is normal, which is how a real finding
  gets waved through. Report it — see SARIF below — and act on it as its own
  piece of work.
- **Upload SARIF to GitHub code scanning** with
  `github/codeql-action/upload-sarif` (SHA-pinned like every other action).
  Run the reporting scan **without** `exit-code` so the upload still happens
  when findings exist, and give the step `if: always()` so a failed gate does
  not swallow the report. That is what makes the non-blocking findings visible
  instead of lost in a log.
- Pin `aquasecurity/trivy-action` by SHA with its tag comment, like everything
  else.
- **Cache the vulnerability database** (`cache: true`, or an explicit
  `~/.cache/trivy` cache). This one is worth it despite the "don't cache
  downloads" rule: the DB is a large artefact pulled from GHCR on every run
  across every job, and the failure mode is a rate-limited registry taking the
  whole pipeline down, not merely a slow step.

**No self-authorised ignores** — same standing rule as everywhere else. Do not
add a `.trivyignore` entry, a `--skip-dirs`, or a severity downgrade to get a
green run. Fix the finding at the source: bump the dependency, change the base
image, fix the misconfiguration. If an entry is genuinely unavoidable, the
user decides, and it carries a comment with the CVE, the reason, and the
condition that lifts it — never a bare ID.

## Path filters — don't trigger for nothing

- A workflow triggered on `push`/`pull_request` must carry a **`paths:`** (or
  `paths-ignore:`) filter so it only runs when files that actually affect it
  change. A multi-arch image `build` must not fire on a docs-only or
  chart-only change; scope it to its real inputs (e.g. `src/**`, `Cargo.toml`,
  `Cargo.lock`, `Dockerfile`, `.dockerignore`, and the workflow file itself).
- **Exception — the `quality` workflow (pre-commit + tests) is never
  path-filtered.** It is the universal gate and must run on every push and pull
  request, whatever changed.
- Tag-triggered workflows (`chart` on `chart-*`, `release` on `v*`),
  `schedule`, and `workflow_dispatch` / `workflow_call` take **no** `paths` —
  path filters do not apply to those events.
- **The `security` workflow is not path-filtered either**, for the same reason
  as `quality`: a new CVE lands without any file changing.

## Concurrency — one run per workflow per ref

**Every** workflow carries a top-level `concurrency:` block keyed on the ref, so
two runs of the same workflow never overlap on the same branch or tag:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

- **`cancel-in-progress: true`, always — no exceptions, publishing workflows
  included.** A run for a superseded commit is dead weight; kill it and free the
  runner. Do not reach for `false` on `release`/`chart` to protect a push
  mid-flight: registries are the place to make a partial publish safe (immutable
  tags, digest-addressed pushes, a re-run of the same tag), not the concurrency
  block. Never write `cancel-in-progress: false`, and never make it conditional
  on the event.
- **In a reusable (`workflow_call`) workflow, hardcode the workflow name in the
  group instead of `${{ github.workflow }}`.** In a called run that expression
  resolves to the **caller**, so `build` would land in the same group as
  `release` and cancel the very job waiting on it. Write
  `group: build-${{ github.ref }}`.
- Key on `github.ref`, not `github.head_ref` — the latter is empty outside
  `pull_request` events and would collapse every push into one shared group.

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
- Never push or publish an image that has not been Trivy-scanned in the same
  job first, and never silence a finding with a `.trivyignore` entry,
  `--skip-dirs` or a severity downgrade to get a green run.
- Never rely on the PR scan alone — without the scheduled re-scan the repo
  only knows about the CVEs that existed on merge day.
- Never ship a workflow without a `concurrency:` group, and never set
  `cancel-in-progress` to anything but `true` — not `false`, not an expression,
  not even on `release`/`chart`.
