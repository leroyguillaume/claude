---
name: github-actions-conventions
description: >-
  GitHub Actions mechanics — workflow file layout, SHA-pinned actions kept
  fresh by Dependabot, `concurrency` groups (and the `workflow_call` trap),
  Trivy SARIF upload to code scanning, `.github/release.yaml` release-note
  categories, GitHub Releases via `gh`, native `ubuntu-24.04-arm` runners,
  `type=gha` build cache, required checks vs `paths` filters. The
  platform-agnostic rules (which pipelines exist, scanning policy, path
  filters, caching) are in `ci-conventions`; load it alongside this one.
  TRIGGER when: editing or creating any file under `.github/workflows/`,
  `.github/actions/`, `.github/release.yaml`, or a composite-action
  `action.yaml`/`action.yml`; setting up CI for a repo hosted on GitHub; user
  asks about GitHub Actions, runners, SARIF, GitHub Releases or release
  notes.
  SKIP when: the repo is not on GitHub (see `gitlab-ci-conventions`), or no
  workflow file is touched and the user isn't asking about GitHub Actions.
---

# GitHub Actions conventions

How the pipelines from `ci-conventions` are written on GitHub. One workflow
file per canonical pipeline: `.github/workflows/quality.yaml`, `build.yaml`,
`security.yaml`, `chart.yaml`, `release.yaml`.

## YAML style

- **No leading `---`** in workflow or other `.github/` config files. Start
  with the first key.
- Write the trigger key as bare **`on:`**, never quoted `"on":`.
- Block style only, consistent with `yaml-conventions`.

## Step naming

- **Every step has a `name:`**. It is mandatory for `uses:` steps and
  expected on `run:` steps. A nameless action step reads as a bare SHA in the
  UI.
- Step names start with a **lowercase letter**: `name: set up the Rust
  toolchain`. Proper nouns keep their capitals (`Rust`, `GHCR`, `GitHub`).
- Keep step names **static**. Never interpolate `${{ }}` into a `name:`.

## Pin actions by SHA

- Pin **every** `uses:` to a full commit SHA, with a trailing comment naming
  the **latest** release tag it corresponds to:
  ```yaml
  - uses: actions/checkout@<40-char-sha>  # v4.2.2
  ```
  Resolve it with `git ls-remote --tags https://github.com/<owner>/<repo>
  '<tag>^{}'`.
- Add **`.github/dependabot.yaml`** with the `github-actions` ecosystem so the
  SHAs and their tag comments are bumped. The rest of that file is
  `dependency-update-conventions`.
- Never use a bare branch or tag ref (`@v4`, `@main`, `@stable`).

## Permissions

Top-level `permissions: contents: read`. Widen only in the job that needs
it: `packages: write` to push to GHCR, `security-events: write` for the SARIF
upload, `contents: write` for `gh release create`, `packages: read` to pull a
private image on the scheduled scan.

## Triggers per workflow

| Workflow | Triggers |
| --- | --- |
| `quality` | `push` to the default branch, `pull_request`, no `paths` |
| `build` | `push`/`pull_request` with `paths`, `workflow_dispatch` and `workflow_call` with `push` and `version` inputs |
| `security` | `push` to the default branch, `pull_request`, `schedule`, `workflow_dispatch`, no `paths` |
| `chart` | `push` of tags `chart-*`, `workflow_dispatch` |
| `release` | `push` of tags `v*` |

Path filters do not apply to tag, `schedule`, `workflow_dispatch` or
`workflow_call` events, so don't write them there.

**A `paths`-filtered workflow must never be a required status check.** When
the filter skips it, the check never reports and the PR waits on it forever.
Only `quality` and `security` (never filtered) go into branch protection.

## `build` and `release`

- Multi-arch: a static `matrix` with `amd64` on `ubuntu-24.04` and `arm64` on
  `ubuntu-24.04-arm`.
- Tags and labels come from **`docker/metadata-action`**: labels on each
  per-arch build, tags in the `manifest` job, consumed from
  `DOCKER_METADATA_OUTPUT_JSON` by `docker buildx imagetools create`.
- Scan before push: `docker/build-push-action` with `load: true`, then
  `trivy image` on the loaded image, then the same build again with a push
  by digest. That second build is a full cache hit, so the pushed layers are
  the ones that were scanned.
- Layer cache: `type=gha,scope=<arch>`. An unscoped `type=gha` cache is
  shared, so the two arch jobs overwrite each other.
- `release` calls `build` through `workflow_call` with `push: true`, then
  `gh release create "$TAG" --generate-notes` gated on the tag containing no
  `-`. For a stable tag, pass `--notes-start-tag` with the previous stable
  tag.

## `.github/release.yaml`

Always present when a `release` workflow exists. `--generate-notes` reads it.
GitHub files a PR under the **first** category whose labels match, so
**Breaking changes comes first**. A breaking PR also carries its usual
`feature`/`fix` label, and only the order keeps it out of that section.

```yaml
changelog:
  exclude:
    labels:
      - ignore-for-release
  categories:
    - title: Breaking changes
      labels:
        - breaking
    - title: Security
      labels:
        - security
    - title: Deprecations
      labels:
        - deprecation
    - title: Features
      labels:
        - feature
    - title: Performance
      labels:
        - performance
    - title: Fixes
      labels:
        - fix
    - title: Documentation
      labels:
        - documentation
    - title: Dependencies
      labels:
        - dependencies
    - title: Maintenance
      labels:
        - chore
    - title: Other changes
      labels:
        - "*"
```

Every label listed here must exist on the repo (see `github-repo-settings`).

## Trivy on GitHub

- `aquasecurity/trivy-action`, SHA-pinned. `cache: true` for the DB.
- The gate step: `exit-code: 1`, `severity: HIGH,CRITICAL`,
  `ignore-unfixed: true`.
- The reporting step: `format: sarif`, **no** `exit-code`, then
  `github/codeql-action/upload-sarif` with `if: always()` so a failed gate
  doesn't swallow the report.
- **Each SARIF upload has its own `category`** (`trivy-fs`, `trivy-image`).
  Code scanning keys alerts on it. Two uploads sharing one replace each other,
  and the first scan's alerts get closed as "fixed".
- The schedule:
  ```yaml
  on:
    schedule:
      - cron: "23 4 * * *"
    workflow_dispatch:
  ```
  **Scheduled workflows only run from the default branch**, and GitHub
  **disables them after 60 days without activity** on a public repo, without
  telling anyone. A dormant repo that still ships an image needs it
  re-enabled from the Actions tab.

## Concurrency

Every workflow has a top-level block:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

- `cancel-in-progress: true`, literally. Never `false`, never an expression.
- **In a `workflow_call` workflow, hardcode the name**:
  `group: build-${{ github.ref }}`. In a called run `github.workflow`
  resolves to the **caller**, so `build` would share `release`'s group and
  cancel the very job waiting on it.
- Key on `github.ref`, not `github.head_ref`. The latter is empty outside
  `pull_request`, and every push would collapse into one group.

## Lint

The `actionlint` pre-commit hook, always, on a repo with workflows.

## Never

- Never start a workflow file with `---`, and never quote `"on"`.
- Never use a bare branch/tag action ref.
- Never make a `paths`-filtered workflow a required check.
- Never share one unscoped `type=gha` cache across architectures.
- Never use `${{ github.workflow }}` in the concurrency group of a reusable
  workflow.
- Never let two SARIF uploads share a `category`.
