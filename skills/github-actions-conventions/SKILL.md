---
name: github-actions-conventions
description: >-
  GitHub Actions mechanics: workflows, pinned actions, SARIF, release notes,
  Releases, Pages.
  TRIGGER when: editing anything under `.github/workflows/` or
  `.github/actions/`, `.github/release.yaml`, or an `action.yaml`/`.yml`;
  setting up CI on GitHub; user asks about Actions, runners, SARIF, GitHub
  Releases or Pages.
  SKIP when: the repo is not on GitHub (`gitlab-ci-conventions`). Load
  `ci-conventions` alongside.
---

# GitHub Actions conventions

How the pipelines from `ci-conventions` are written on GitHub. One workflow
file per canonical pipeline the repo needs: `.github/workflows/quality.yaml`,
`build.yaml`, `security.yaml`, `chart.yaml`, `release.yaml`, `docs.yaml`.
`ci-conventions` says which ones a repo has; a repo with no lockfile and no
published image has no `security.yaml`.

## YAML style

Write the trigger key as bare **`on:`**, never quoted `"on":`. Everything else
is `yaml-conventions`.

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
  - uses: actions/checkout@<40-char-sha>  # vX.Y.Z
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

A called workflow can only keep or narrow the `GITHUB_TOKEN` scope of the job
that calls it, never widen it. The `release` job that runs `uses:
./.github/workflows/build.yaml` therefore grants `packages: write` itself;
without it the push is denied however `build.yaml` declares its own
permissions.

## Triggers per workflow

| Workflow | Triggers |
| --- | --- |
| `quality` | `push` to the default branch, `pull_request`, no `paths` |
| `build` | `push`/`pull_request` with `paths`, `workflow_dispatch` and `workflow_call` with `push` and `version` inputs |
| `security` | `push` to the default branch, `pull_request`, `schedule`, `workflow_dispatch`, no `paths` |
| `chart` | `push` of tags `chart-*`, `workflow_dispatch` |
| `release` | `push` of tags `v*` |
| `docs` | `push` to the default branch and `pull_request` with `paths`, `workflow_dispatch` |

Path filters do not apply to tag, `schedule`, `workflow_dispatch` or
`workflow_call` events, so don't write them there.

`chart` runs the same version drift guard as `release` before it packages
(`release-script-conventions`).

**A `paths`-filtered workflow must never be a required status check.** When
the filter skips it, the check never reports and the PR waits on it forever.
Only `quality` and, when it exists, `security` (never filtered) go into
branch protection.

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

## `docs` and GitHub Pages

What the pipeline does is in `starlight-conventions`. On GitHub:

- **Pages source is "GitHub Actions"**: checking and switching it on is
  `github-repo-settings`' job. A custom domain is set in the repository's
  Pages settings, and the site's `site`/`base` follow it. No `CNAME` file is
  needed with an Actions deployment.
- Two jobs. `build` checks out with `fetch-depth: 0` (the release tags), runs
  `actions/setup-node` with `node-version-file: docs/.nvmrc`, `npm ci`, and the
  versioned build, then `actions/upload-pages-artifact` with `path: docs/dist`
  on non-PR runs of the default branch only. `deploy` (`needs: build`, same
  condition) runs `actions/deploy-pages` in `environment: github-pages` with
  `url: ${{ steps.deploy.outputs.page_url }}`.
- `permissions: pages: write` and `id-token: write` on `deploy` alone; the
  workflow stays `contents: read`.
- **The `github-pages` environment deploys from the default branch only**, so
  a tag run cannot deploy. After a stable release, `release` dispatches the
  docs on the default branch, in a job that `needs:` the GitHub Release job
  (skipped for an rc, so the docs are too):
  ```yaml
  docs:
    name: docs
    needs:
      - github-release
    permissions:
      actions: write
    runs-on: ubuntu-24.04
    steps:
      - name: rebuild the documentation site
        env:
          GH_TOKEN: ${{ github.token }}
          DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}
        run: gh workflow run docs.yaml --repo "$GITHUB_REPOSITORY" --ref "$DEFAULT_BRANCH"
  ```
  A `workflow_dispatch` sent with `GITHUB_TOKEN` does start a run, unlike most
  events that token triggers.
- `docs` is `paths`-filtered, so it is never a required check. The site's
  tests run in `quality`, in their own job.
- No npm cache in `setup-node`: it caches a download.

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
  doesn't swallow the report. A pull request from a fork gets a read-only
  `GITHUB_TOKEN`, so the upload fails there; guard it to same-repository
  runs:
  ```yaml
  if: >-
    always() && (github.event_name != 'pull_request'
    || github.event.pull_request.head.repo.full_name == github.repository)
  ```
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
- Never deploy Pages from a tag run; dispatch the docs on the default branch.
