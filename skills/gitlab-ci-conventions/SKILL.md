---
name: gitlab-ci-conventions
description: >-
  GitLab CI mechanics, any instance or tier: rules, includes, scans, releases,
  Pages.
  TRIGGER when: editing `.gitlab-ci.yml`, `.gitlab/ci/`,
  `.gitlab/changelog_config.yml` or a CI/CD component `templates/*.yml`;
  setting up CI on GitLab; user asks about GitLab CI rules, runners,
  schedules, the vulnerability report, Releases or Pages.
  SKIP when: the repo is on GitHub (`github-actions-conventions`). Load
  `ci-conventions` alongside.
---

# GitLab CI conventions

How the pipelines from `ci-conventions` are written on GitLab. The skill
assumes nothing about the instance. Runner tags, registry host and tier all
vary, so read them from the repo or ask. Never guess a runner tag.

## Layout and style

- One `.gitlab-ci.yml`. Once it passes a couple of hundred lines, split it
  into `.gitlab/ci/<pipeline>.yml` (`quality`, `build`, `security`, `chart`,
  `release`, `docs`), pulled in with `include: local:`.
- Each canonical pipeline is a **set of jobs**, not a file. Name jobs in
  lowercase kebab-case after what they do (`pre-commit`, `test`,
  `build-image`, `trivy-fs`), and keep them static. A `parallel: matrix`
  already suffixes the name.
- **`rules:` only.** Never `only:`/`except:`. They can't be combined with
  `rules:` and they hide the real trigger logic.
- `needs:` to build a DAG. Stages are for ordering the UI, not for
  sequencing jobs.
- Shared rules go through `!reference [.rules-build, rules]` rather than YAML
  anchors, because anchors don't cross `include:` boundaries. pre-commit's
  `check-yaml` rejects custom tags, so give it the `--unsafe` arg in a repo
  that uses `!reference`.
- Block style, no leading `---`, per `yaml-conventions`.

## The pipeline header

```yaml
workflow:
  auto_cancel:
    on_new_commit: interruptible
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH
    - if: $CI_COMMIT_TAG

default:
  interruptible: true
```

- Without the second rule, a push to a branch with an open MR runs **two
  pipelines**, a branch one and an MR one.
- `interruptible: true` on **every** job, publishing included. That is the
  GitLab form of the "cancel superseded runs" rule. Never override it to
  `false`. Auto-cancel also needs the project setting *Auto-cancel redundant
  pipelines*, which is on by default. Leave it on.

## `rules:changes` traps

- **`changes` is always true** on tag pipelines, scheduled and manual
  pipelines, and the first push of a new branch. A job filtered only by
  `changes` therefore runs on every schedule. Pair `changes` with an `if:` on
  the pipeline source:
  ```yaml
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
      when: never
    - if: $CI_PIPELINE_SOURCE == "merge_request_event" || $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      changes:
        paths:
          - src/**/*
          - Cargo.toml
          - Cargo.lock
          - Dockerfile
          - .dockerignore
          - .gitlab/ci/build.yml
  ```
- In an MR pipeline, `changes` compares against the target branch. On a
  branch pipeline without an MR, add `compare_to: refs/heads/<default>`.
  Otherwise it compares against the previous push only.
- A job skipped by `rules` doesn't block *Pipelines must succeed*. A pipeline
  with **no** job does. Because `quality` always runs, that never happens.

## Pinning `include:`

```yaml
include:
  - component: $CI_SERVER_FQDN/<group>/<project>/<name>@<40-char-sha>  # 1.4.0
  - project: <group>/<project>
    ref: <40-char-sha>  # v1.4.0
    file: /templates/build.yml
```

- A full SHA with the version as a comment, bumped by Renovate
  (`dependency-update-conventions`). Never a branch, never a bare tag.
- No `include: remote:` from a URL you don't control. Mirror the file into a
  project and include it by SHA.
- `include: local:` is the repo itself and needs no pin.

## Publishing credentials

- **Protect the release tag patterns** (`v*`, `chart-*`) so that only
  maintainers can create them.
- Registry and API credentials for publishing are CI/CD variables that are
  **protected** and **masked** (hidden where the instance supports it).
  Protected variables only reach pipelines on protected branches and tags,
  so an MR pipeline never sees them. That is the whole point.
- Restrict `CI_JOB_TOKEN` access to the projects that actually need it (the
  job token allowlist).

## `build`

Define `IMAGE` once in top-level `variables:` (`$CI_REGISTRY_IMAGE` when
using the GitLab registry, otherwise the organisation's registry). Tags and
OCI labels derive from `$CI_COMMIT_TAG`, `$CI_COMMIT_SHA` and
`$CI_PROJECT_URL`, and are computed in one place.

- One job with a `parallel: matrix` over `ARCH` and a per-arch runner in
  `tags:`. Ask the user which runner tags exist.

  ```yaml
  parallel:
    matrix:
      - ARCH:
          - amd64
          - arm64
  ```

- In the same job: `docker buildx build --load --platform linux/$ARCH`, then
  the two Trivy scans (below) on the loaded image, then, only when pushing,
  the same build again with
  `--output type=image,push-by-digest=true,name-canonical=true,push=true`.
  It is a cache hit, so the pushed layers are the ones that were scanned.
  Write the digest to an artifact file per arch.
- A `manifest` job (`needs:` both arch jobs, pushing runs only) assembles
  the tags with `docker buildx imagetools create`.
- Layer cache: `--cache-from type=registry,ref=$IMAGE:buildcache-$ARCH` always,
  `--cache-to` only on pipelines that hold push credentials.
- Push is enabled on tag pipelines and on manual (`web`) runs with a
  `PUSH: "true"` variable. MR pipelines never push.

## Trivy on GitLab

- The official Trivy image, pinned to an exact version. `TRIVY_CACHE_DIR:
  $CI_PROJECT_DIR/.cache/trivy` with a `cache:` on that path, because
  `cache:` only saves paths inside the project directory.
- The reporting scan runs **first**, with `--exit-code 0`, then the gate
  (`--exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed`). Reports are
  uploaded with `artifacts: when: always`.
- Reports, using the templates shipped in the image (`@/contrib/…`), never
  downloaded:
  - **every tier**: `--format template --template @/contrib/junit.tpl` into
    `artifacts: reports: junit:`, which shows up in the MR widget;
  - **Ultimate**: also `@/contrib/gitlab.tpl` into
    `artifacts: reports: container_scanning:` for the image. The project
    vulnerability report is **only fed from default-branch pipelines**, so
    the scan has to run there.

## Schedules

Pipeline schedules live in the project settings, not in the repo, so
`CONTRIBUTING.md` documents each one (cron, ref, variables).

- The security schedule sets `SCHEDULE_TASK: security`, and jobs select on
  `$CI_PIPELINE_SOURCE == "schedule" && $SCHEDULE_TASK == "security"`. Other
  schedules (Renovate, …) pick their own value, and every other job has a
  `when: never` rule for `schedule`.
- Find the latest stable release with `git ls-remote --tags origin 'v*'`
  rather than `git tag`, since the clone is shallow.
- A schedule runs as its owner and **is deactivated when that user is blocked
  or removed**. Own it with a bot or service account.

## `release`

On `$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/` only. The regex is what keeps
`-rcN` tags from getting a release page, while `build` still pushes them.

```yaml
release:
  stage: release
  needs:
    - manifest
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  script:
    - scripts/release-notes.sh > release-notes.md
  release:
    tag_name: $CI_COMMIT_TAG
    description: release-notes.md
```

- `scripts/release-notes.sh` gets the notes from the **changelog API** (`GET
  /projects/:id/repository/changelog?version=<v>&from=<previous stable
  tag>`), called with a protected project access token with `read_api`.
  `CI_JOB_TOKEN` only reaches a short allowlist of endpoints.
- The API groups commits by their **`Changelog:` git trailer** (`added`,
  `fixed`, `security`, `deprecated`, `performance`, `removed`, `other`),
  titled by `.gitlab/changelog_config.yml`. The trailer must be on the commit
  that lands on the default branch. With squash merges, that is the squash
  commit message, set in the MR.
- The job image must carry the release tool the instance expects (`glab` or
  the older `release-cli`).

## `chart`

On `$CI_COMMIT_TAG =~ /^chart-\d+\.\d+\.\d+$/` and manual runs: `helm
package --version <v>` then `helm push` to `oci://<registry>/charts`, after the
same version drift guard as `release` (`release-script-conventions`).

## `docs` and GitLab Pages

What the pipeline does is in `starlight-conventions`. On GitLab:

- **Any pipeline that runs a Pages job deploys**, whatever its ref; there is no
  environment protection to fall back on. The `rules` are the only guard.
- Two jobs. `docs-build` runs on MRs touching the site (validation only) and
  on the default branch. `pages` deploys: a job with the `pages:` keyword,
  `pages: publish: public`, run on the default branch only, never on a
  schedule:
  ```yaml
  pages:
    stage: deploy
    image: node:24.11.1-bookworm-slim  # the version in docs/.nvmrc
    variables:
      GIT_DEPTH: 0
    rules:
      - if: $CI_PIPELINE_SOURCE == "schedule"
        when: never
      - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_PIPELINE_SOURCE == "pipeline"
      - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
        changes:
          paths:
            - docs/**/*
            - logo.svg
            - .gitlab/ci/docs.yml
    script:
      - git fetch --tags --force origin
      - npm ci --prefix docs
      - npm --prefix docs run build:versions
      - mv docs/dist public
    pages:
      publish: public
  ```
  `docs-build` is the same script without `pages:`, with the MR rule instead.
  On an instance older than the `pages:` keyword, the job must be named
  `pages` and publish `public` through `artifacts: paths:`.
- `GIT_DEPTH: 0` plus an explicit `git fetch --tags`: the runner's fetch
  refspecs do not bring the release tags, and a shallow clone sees no version.
- **After a stable release, deploy from the default branch, not the tag.** The
  `release` job's pipeline triggers one on the default branch, which arrives
  with `$CI_PIPELINE_SOURCE == "pipeline"` (hence the `pages` rule above):
  ```yaml
  docs:
    stage: release
    needs:
      - release
    rules:
      - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
    trigger:
      project: $CI_PROJECT_PATH
      branch: $CI_DEFAULT_BRANCH
  ```
- **The URL depends on the instance and the project**: new projects get a
  unique domain served at `/`, others `<group>.<pages-domain>/<project>`, and
  a custom domain overrides both. Read it from the project's Pages settings
  before setting `site`/`base`.
- Parallel deployments (`pages: path_prefix:`) are not how versions are
  served: every version is built into the one artifact.

## Lint

- The `check-gitlab-ci` hook from `check-jsonschema`, which validates against
  the vendored schema and understands `!reference`.
- It doesn't resolve `include:`. `glab ci lint` does, but it needs the API,
  so it is a manual check and not a hook.

## Never

- Never use `only:`/`except:`, and never filter a job with `changes` alone.
- Never set `interruptible: false`.
- Never include a template or component by branch, bare tag or remote URL.
- Never make publishing credentials unprotected, and never push from an MR
  pipeline.
- Never download a Trivy report template at run time.
- Never create a GitLab Release for a tag with a `-`.
- Never let a Pages job run outside the default branch.
