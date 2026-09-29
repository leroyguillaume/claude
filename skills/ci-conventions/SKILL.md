---
name: ci-conventions
description: >-
  Platform-agnostic CI conventions — the canonical
  quality/build/security/chart/release pipelines, a single pre-commit + tests
  quality gate, mandatory Trivy vulnerability scanning (scan before push, gate
  on HIGH/CRITICAL, daily re-scan of what is published), path filtering and
  its exceptions, cancelling superseded runs, least privilege, immutable
  references, pragmatic caching, native multi-arch builds, tag-driven
  releases. Load `github-actions-conventions` or `gitlab-ci-conventions`
  alongside for the platform syntax.
  TRIGGER when: creating or editing any CI definition (`.github/workflows/`,
  `.github/actions/`, `.gitlab-ci.yml`, `.gitlab/ci/`, or any other CI
  system's pipeline file); setting up CI for a new repo; deciding what a
  pipeline runs, when it triggers, what it publishes or how it scans; user
  asks about CI design, pipeline triggers, path filters, CVE/image scanning,
  CI caching, multi-arch builds or release automation.
  SKIP when: no pipeline file is touched and the user isn't asking about CI.
---

# CI conventions

What a pipeline does and why, whatever runs it. The *how* for a given
platform is in `github-actions-conventions` or `gitlab-ci-conventions`.

## The canonical pipeline set

Create exactly these, conditioned on what the repo contains. The platform
skill says how each one maps onto files and triggers.

- **`quality`**: always. It runs `pre-commit run --all-files` **and** the test
  suite, on every change proposal (PR/MR) and on every push to the default
  branch. The `language: system` hooks shell out to real binaries, so the job
  installs **every** tool the hooks need (toolchain + `helm`, `helm-docs`,
  `hadolint`, …) before running `pre-commit`. This is the single quality
  gate. Don't scatter fmt/lint/test across ad-hoc pipelines.
- **`build`**: when a `Dockerfile` exists. It builds the image, scans it, and
  **pushes only when asked**, meaning a manual run with a `push` input or the
  `release` pipeline. A plain push or change proposal builds and scans
  without pushing (validation only). Tags and labels come from the
  platform's metadata (a metadata action, predefined variables). Never
  hand-roll tag strings in several places.
- **`security`**: always. The Trivy vulnerability scans (below), on every
  change proposal, on push to the default branch, **daily on a schedule**,
  and on manual trigger.
- **`chart`**: when a Helm chart exists. It publishes the chart as an **OCI
  artefact**. The chart has its **own release lifecycle**, decoupled from the
  app. It triggers on the `chart-X.Y.Z` tag namespace (plus manual runs) and
  never on a change proposal, where `helm lint` inside `pre-commit` is the
  validation. The chart version comes from the tag
  (`helm package --version <v>`). `appVersion` stays whatever `Chart.yaml`
  pins. It runs the same drift guard as `release`, which covers
  `Chart.yaml` and the README's `helm install --version`. A chart tag never
  gets a release page. The only release pages are the app's.
- **`release`**: always. It is the app-release orchestrator, triggered by a
  `vX.Y.Z` tag. It derives the version from the tag, **refuses to run when
  the committed version disagrees** (the drift guard in
  `release-script-conventions`), runs `build` with push enabled, then creates
  the platform's release page with generated notes. It does **not** publish
  the chart.

### Pre-release tags

**A pre-release tag (`vX.Y.Z-rcN`, any tag with a `-`) publishes the image and
stops there: no release page.** An rc exists to be tested. A release page for
it would carry the full generated changelog, and the final release would then
repeat it (or, diffed against the rc, show almost nothing).

For a stable release, the notes start from the **previous stable tag** (the
greatest `vX.Y.Z` without a hyphen below the current one, `sort -V`), never
from an rc. With no previous stable tag, let the platform pick.

## Trivy: always, and not only as a gate

**Every repo runs Trivy in CI.** `trivy config` already runs in `pre-commit`
(the `DS-`/`KSV-`/`AVD-` misconfiguration checks, see `docker-conventions`,
`helm-conventions`, `terraform-conventions`). CI is where the *vulnerability*
side lives, because it needs a database that changes every day and a network
to fetch it. A misconfiguration is deterministic and belongs at commit time.
A CVE appears against code nobody touched. **A repo that only scans on change
proposals is scanning the day it merged, not today.**

What to run:

- **`trivy image`** on the image `build` just produced, **in the same job,
  before anything is pushed**, change proposals included. Build into the
  local store or a tarball, scan, then push that same image. Publishing a
  known-vulnerable image and scanning it afterwards is the wrong order, and a
  "staging" tag in a registry is still a published image.
- **`trivy fs`** on the checkout, for the lockfiles (`Cargo.lock`, `uv.lock`,
  `package-lock.json`) and secrets. This is what catches a vulnerable
  transitive dependency the manifest never mentions.

How to run it:

- **Fail on `HIGH` and `CRITICAL`**, and use `ignore-unfixed` on that
  blocking gate only. A CVE with no upstream fix can't be actioned by the
  contributor in front of it. Blocking on it teaches everyone that red is
  normal, which is how a real finding gets waved through.
- **Report everything else where people look**: the platform's code-scanning
  or vulnerability report, via a second, non-failing scan whose upload runs
  even when the gate failed. A finding that only exists in a job log is lost.
- **Pin the Trivy version** (action SHA, image tag) like any other tool, and
  use the report templates shipped with that version. Never fetch a template
  from a branch URL at run time.
- **Cache the vulnerability DB.** It is a large artefact pulled from a
  registry on every run, and the failure mode is a rate-limited registry
  taking the whole pipeline down. Behind a registry proxy, point
  `--db-repository` / `--java-db-repository` at the mirror.

### The scheduled re-scan

- **Daily**, at an **off-hour minute** (never `0`). Top-of-the-hour runs are
  the first to be delayed or dropped under load.
- **Scan what is published, not a rebuild.** A scheduled run has no fresh
  build, and rebuilding `main` would pull patched base layers and report a
  clean image nobody runs. It scans the image of the **latest stable
  release**, pulled by its tag. `trivy fs` runs on the default branch as
  usual. A repo with no image runs `trivy fs` alone.
- **Keep the gate.** Nobody waits on a cron, so a red scheduled run *is* the
  notification that a new `HIGH`/`CRITICAL` CVE exists.

**No self-authorised ignores.** Don't add a `.trivyignore` entry, a
`--skip-dirs`, or a severity downgrade to get a green run. Fix at the source:
bump the dependency, change the base image. If an entry is genuinely
unavoidable, the user decides, and it carries a comment with the CVE, the
reason, and the condition that lifts it.

## Path filters: don't trigger for nothing

- A pipeline triggered by a push or a change proposal only runs when a file
  that affects it changes. A multi-arch image `build` does not fire on a
  docs-only or chart-only change. Scope it to its real inputs (e.g. `src/**`,
  `Cargo.toml`, `Cargo.lock`, `Dockerfile`, `.dockerignore`, and its own
  pipeline file).
- **`quality` and `security` are never path-filtered.** One is the universal
  gate. For the other, a new CVE lands without any file changing. Because
  `quality` always runs, a proposal is also never left without a pipeline.
- Tag, schedule and manual triggers take **no** path filter.
- **Only unfiltered jobs are made required for merging.** A required check
  that a path filter skipped can block the merge forever. The platform skill
  has the specific trap.

## Cancel superseded runs, always

Two runs of the same pipeline never overlap on the same ref. The newer one
**cancels** the older one, **publishing pipelines included**. A run for a
superseded commit is dead weight. Make a partial publish safe at the
registry (immutable tags, digest-addressed pushes, re-runnable tags), never
by letting stale runs finish.

## Least privilege and immutable references

- Every job gets the **smallest token scope** it needs, widened only in the
  job that needs more (publishing, uploading a report).
- **Publishing credentials exist only where publishing happens**: tag
  pipelines, or manual runs on the default branch. A change-proposal pipeline
  never sees them.
- **Every reference to third-party pipeline code is immutable**: an action or
  an included template/component pinned to a full commit SHA with the
  version in a comment, kept fresh by the dependency bot
  (`dependency-update-conventions`). A mutable tag or branch is somebody else's
  deploy key into your pipeline.
- Tool images are pinned to an exact version tag, never `latest`.

## Cache deliberately

Cache what is expensive to **recompute**, not what is cheap to
**re-download**. Restoring a large dependency cache can be slower than a
clean fetch, and a stale cache is worse than none.

- **Keep**: the Docker layer cache, **scoped per architecture** so the arch
  jobs never clobber each other, and compiled-dependency caches (`cargo-chef`
  in the `Dockerfile`, a Rust build cache for non-Docker jobs). These cache
  CPU work.
- **Skip**: a cache wrapped around a fast download just because you can.
  Measure before adding one. (The Trivy DB is the exception, see above.)

## Multi-arch builds on native runners

- A multi-arch image is a **static matrix over both architectures**, `amd64`
  and `arm64`, each on its **own native runner**, change proposals included.
  Never drop an architecture to save time.
- **Never QEMU-emulate a Rust build.** If no native runner exists for an
  architecture, say so to the user rather than falling back to emulation.
- When pushing, each arch job pushes **by digest**, and a final `manifest`
  job assembles the multi-arch manifest and applies the tags. That job runs
  only when pushing.

## Never

- Never push an image or publish a chart from a change-proposal pipeline.
- Never push an image, under any tag, before it has been Trivy-scanned in the
  same job.
- Never gate on anything but fixable `HIGH`/`CRITICAL`, and never silence a
  finding to get a green run.
- Never rely on the change-proposal scan alone. Without the daily re-scan of
  the published image, the repo only knows the CVEs that existed on merge day.
- Never split the quality gate, and never path-filter `quality` or
  `security`.
- Never let two runs of one pipeline overlap on a ref, and never exempt a
  publishing pipeline from cancellation.
- Never create a release page for a pre-release tag, and never start a stable
  release's notes from an rc.
- Never reference third-party pipeline code by a mutable ref.
