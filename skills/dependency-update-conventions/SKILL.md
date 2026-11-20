---
name: dependency-update-conventions
description: >-
  Renovate configuration and its PRs; Dependabot version updates are not used.
  TRIGGER when: editing `renovate.json`/`.json5`, `.renovaterc`, a `renovate`
  key in `package.json`; a repo has `.github/dependabot.yml`/`.yaml`; setting
  up automated updates; adding a custom manager; triaging or merging bot PRs,
  especially failing ones; user asks about update grouping or scheduling.
  SKIP when: bumping a dependency by hand with no bot involved.
---

# Dependency-update conventions

## Renovate, and only Renovate

**Renovate owns every dependency update, on every platform.** One bot, one
config, one review flow: the same `renovate.json` shape on GitHub and on
GitLab, custom managers for the version strings no ecosystem knows about
(a chart version in a catalog, a tool in a `Dockerfile` `ARG`), the `mise`
manager for `mise.toml` and `mise.lock`, and grouping and scheduling rules
that apply across all of them. A second bot only adds a second config to keep
in step and a second place for a bump to come from.

**Dependabot version updates are not used.** A repository that still has a
`.github/dependabot.yaml` moves over in one PR:

1. Map each Dependabot ecosystem to the Renovate manager that covers it
   (`github-actions`, `cargo`, `npm`, `pip_requirements`/`pep621`,
   `dockerfile`, `pre-commit`, …), and carry its groups, cooldown and labels
   over to `packageRules`, `minimumReleaseAge` and `labels`.
2. Delete `.github/dependabot.yaml` in the same PR, so no ecosystem has two
   owners for even one run.
3. Turn Dependabot **security updates** off: Renovate's `vulnerabilityAlerts`
   opens the security PRs, and both would open one for the same bump. Leave
   Dependabot **alerts** on — they are where Renovate reads the advisories
   from (`github-repo-settings`).

**Pins stay pins.** The `github-actions` manager bumps a SHA-pinned `uses:`
together with its trailing `# vX.Y.Z` comment, and the `pre-commit` manager a
`rev: <sha>  # frozen: <tag>` line — but `pre-commit` is **off by default**
and must be enabled, or the hook revisions silently stop moving.

## Never automerge

**No automerge, in any form.** Not `automerge: true`, not an automerge preset
(`:automergeMinor`, `:automergeDigest`, …), not `platformAutomerge`, and not
a workflow that runs `gh pr merge --auto` on a bot PR.

The reason is not fear of breakage — it is that **a dependency bump is a
change to production that nobody read**. Green CI is not a review: it proves
the tests that already existed still pass, which is exactly the bar a
compromised release is built to clear. The supply-chain attacks that matter
all ship a version whose test suite is green.

**`platformAutomerge: false` does not disable automerge**, and reads as though
it does. It only chooses *who* merges: with `automerge: true` still set,
Renovate merges the PR itself instead of handing GitHub's auto-merge the job.
A config carrying `"platformAutomerge": false` next to `"automerge": true` is
an automerging config.

The cost is real and is paid deliberately: someone presses merge. Bring the
number of presses down with **grouping and scheduling**, never with automerge:

- group patch and minor updates per ecosystem into one PR; keep every major
  on its own, because that one needs the release notes read;
- **group what must move together** — a different reason, which prevents
  breakage rather than noise; see the next section;
- `minimumReleaseAge` so a release has to survive a few days in the wild
  before it is proposed;
- `prConcurrentLimit` so the queue stays a queue and not a wall.

## Group what must move together

Some packages are released in lockstep: a core crate and its SDK and
exporters, a framework and its integrations, two charts version-locked
upstream, the chart and the CRD set that are two sources of one `Application`.
A bot opens **one PR per package**, and each of them is broken on its own —
either it fails to build, or it merges alone and runs a combination nobody
tested.

**Spot it on the PRs themselves.** Several bot PRs for the same family, opened
together, all red with type or trait mismatches between sibling packages
(`expected X, found X` naming two versions of one crate, a method or trait
impl that "does not exist" on a type from the sibling), are one lockstep
group, not N bugs. Bumping one member leaves two versions of the core in the
dependency graph; that is the whole error.

**Then, instead of patching each PR:**

1. Open one PR that bumps the whole family together, and fix the code there
   if the new release genuinely needs it — usually it does not.
2. Add the group to the bot config **in that same PR**, so the next release
   arrives as one PR.
3. Close the bot PRs it supersedes, each with a comment naming the PR that
   replaces them.

**The group takes every update type, majors included.** A lockstep family
breaks on a major exactly as on a minor, and `0.x` families bump the minor for
a breaking release anyway. `config:recommended` already groups the monorepos
it knows (`group:monorepos`); add a rule only for a family it misses, and
match by file (`matchFileNames`) when a member's `depName` is a git URL rather
than a package name. Put the lockstep rule **after** the patch/minor
catch-all: when several `packageRules` match, the later one's `groupName`
wins.

```json
{
  "packageRules": [
    {
      "description": "Minor and patch bumps land as one PR; each major gets its own",
      "matchUpdateTypes": ["minor", "patch"],
      "groupName": "minor and patch"
    },
    {
      "description": "SDK and exporters only compile against the matching opentelemetry release",
      "matchPackageNames": ["opentelemetry*"],
      "groupName": "opentelemetry"
    }
  ]
}
```

Families that are known to move together — examples, not a whitelist; the
failing PRs above are the real signal:

| Ecosystem | Family |
| --- | --- |
| cargo | `opentelemetry*`; `tonic*` with `prost*`; `aws-sdk-*` with `aws-config`, `aws-smithy-*`; `aide` with `schemars`, `axum`, `axum-extra` |
| npm | `@astrojs/*` with `astro`; `react` with `react-dom`; `@typescript-eslint/*` |
| pip | `boto3` with `botocore` |
| Helm / Argo CD | a chart and its separately-sourced CRDs |

## Dependency dashboard on

**`dependencyDashboard: true`, always.** It is the only place that shows what
Renovate decided *not* to open a PR for — rate-limited, blocked by a failed
lookup, awaiting approval, deprecated datasource, explicitly ignored.

Without it, **silence is ambiguous**: no PR for three months reads as "nothing
to update" and means "the manager stopped matching after a refactor" just as
often. The dashboard is what turns that into a visible list.

```json
{
  "dependencyDashboard": true,
  "dependencyDashboardTitle": "Dependency dashboard"
}
```

- **Automerge breaks the dashboard, which is the second reason not to use
  it.** Renovate writes the dashboard only on a pass that does not end in an
  automerge, and gives up after one retry — so a run that merges anything
  leaves the dashboard stale, and a repo that merges most days leaves it stale
  for months. The known workaround is a second Renovate pass forced with
  `RENOVATE_FORCE: '{"automerge":false}'` purely to reach the dashboard write.
  Not automerging removes both the staleness and the workaround.
- `dependencyDashboardApproval: true` for majors is a good pairing with
  no-automerge on a busy repo: the major waits on the dashboard until someone
  ticks it, instead of sitting open as a stale PR.

## Renovate configuration

**Document rules with Renovate's own `description` field, not with comments.**
Every `packageRules` entry, `customManagers` entry and custom datasource takes
a `description`, and Renovate surfaces it — in the dependency dashboard and in
the PR body — where a JSON5 comment is visible only to whoever opens the file.
A rule whose match is not self-evident, a pin with a reason, an `ignoreDeps`
entry: `description`, every time.

That settles the file format: plain **`renovate.json`** is enough, because the
documentation lives in the config rather than around it. Reach for
`renovate.json5` only for commentary that genuinely should not appear in a PR
body.

Baseline:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "timezone": "Europe/Paris",
  "dependencyDashboard": true,
  "prConcurrentLimit": 5,
  "minimumReleaseAge": "3 days"
}
```

- **The baseline sets no label.** When the repo has `.github/release.yaml`,
  add `"labels": ["<changelog-category label>"]` so bot PRs land in the
  right release-notes section — see `github-pr-conventions`, and read the
  repo's actual labels rather than inventing one. Without that file, set no
  category label. **Renovate applies no label** unless `labels` is set;
  relabelling a bot PR by hand is lost on the next one, so fix the config.
- **Match the repository's commit style**, read from `git log --oneline`
  rather than assumed. Renovate's default is `chore(deps): …`; a repo writing
  lowercase `<area>: <imperative>` subjects sets `semanticCommits: "disabled"`
  and its own `commitMessage*` keys.

  **The `commitMessage*` keys belong in a `packageRules` entry matching every
  package, not at the top level** — manager defaults (`Helm release
  {{depName}}`, and one per manager) beat top-level `commitMessage*`, so a
  top-level setting silently applies to some managers and not others:

  ```json
  {
    "matchPackageNames": ["*"],
    "commitMessagePrefix": "{{depName}}:",
    "commitMessageAction": "bump",
    "commitMessageTopic": "to {{newVersion}}",
    "commitMessageExtra": ""
  }
  ```
- **`rangeStrategy`**: `pin` for an application (the deployed version belongs
  in git), `bump` or the ecosystem default for a published library (pinning a
  library's ranges pushes the conflict onto its consumers).
- Schedule off-hours if the repo is noisy, but **never schedule security
  updates away** — leave `vulnerabilityAlerts` unrestricted: with Dependabot
  security updates off, it is the only thing opening security PRs.

### Scope the built-in managers before writing a custom one

Renovate ships managers for far more than lockfiles, and in a GitOps repo they
do most of the work: **`argocd`** (chart versions in `Application` manifests),
**`helm-values`**, **`crossplane`**, **`kubernetes`**, **`pre-commit`**. Check
whether one already sees your file before reaching for a regex.

Most of them are **off, or scoped to filenames that do not match your layout**,
until you point them at it — that is the usual reason "Renovate isn't picking
this up":

```json
{
  "argocd": {
    "managerFilePatterns": ["/^apps/.*\\.yaml$/"]
  },
  "helm-values": {
    "managerFilePatterns": ["/(^|/)values\\.ya?ml$/"]
  },
  "pre-commit": { "enabled": true }
}
```

### Custom datasources

When the *manager* exists but nothing knows how to list versions — a dashboard
id on a vendor's API, an internal index — declare a `customDatasources` entry
with a `transformTemplates` JSONata expression mapping the response onto
`releases[].version`. It pairs with a custom manager: the manager finds the
string, the datasource says what newer looks like.

Give it a `versioningTemplate` that matches reality. A bare incrementing
integer with `semver` versioning classifies **every** bump as a major, which
then trips whatever gate you put on majors — use a `regex:` versioning instead
and say so in the `description`.

### Custom managers

The reason Renovate is there at all, usually. Each one needs a `description`
saying which file it matches and quoting a line it matches — a regex over
someone else's format is unreadable six months later:

```json
{
  "customManagers": [
    {
      "description": "Chart versions in the app catalog, e.g. `// renovate: datasource=docker depName=…` followed by `version: '1.2.3',`",
      "customType": "regex",
      "managerFilePatterns": ["/^apps/[^/]+/catalog\\.libsonnet$/"],
      "matchStrings": ["datasource=(?<datasource>\\S+) depName=(?<depName>\\S+)\\s+version: '(?<currentValue>[^']+)'"],
      "versioningTemplate": "semver"
    }
  ]
}
```

**Dry-run a custom manager before merging it** (`renovate --dry-run`, or the
debug log of the next run). A regex that matches nothing fails silently — it
just never opens a PR, which looks exactly like being up to date. That is also
what the dashboard is for.

## Running Renovate

**Self-hosted, from the repository's own CI**, not the hosted Mend app: the
config, the schedule and the logs stay in the repository. It is also the
only option that lets you dry-run on demand.

A workflow that follows `github-actions-conventions` — SHA-pinned action,
`concurrency`, least-privilege `permissions`, lowercase step names — plus two
things specific to Renovate:

- **A dedicated `RENOVATE_TOKEN`, not `GITHUB_TOKEN`.** A PR opened with
  `GITHUB_TOKEN` does not trigger other workflows, so every Renovate PR would
  arrive with no CI on it — which is exactly the check the whole review flow
  rests on. The job's own `permissions` stay `contents: read`: the token does
  the writing, not the workflow. A fine-grained token also needs **Dependabot
  alerts: read**, or `vulnerabilityAlerts` has nothing to act on.
- **A `workflow_dispatch` `dryRun` input** wired to `RENOVATE_DRY_RUN`, and a
  `logLevel` choice input. This is what makes "dry-run a custom manager before
  merging it" a thing somebody can actually do, rather than advice.

Schedule it (`cron`) rather than running it on push: dependency updates are
not a property of a commit.

On GitLab the same run is a scheduled pipeline job with the token in a masked
CI/CD variable (`gitlab-ci-conventions`).

**Never:**

- Never enable automerge, in any form — including a workflow that merges bot
  PRs for you.
- Never add a `.github/dependabot.yaml`, and never leave Dependabot security
  updates on beside Renovate.
- Never turn the dependency dashboard off.
- Never add a custom manager without a `description` quoting the line it
  matches, and never merge one without a dry run.
- Never leave the `pre-commit` manager off in a repo with a
  `.pre-commit-config.yaml`.
- Never take `platformAutomerge: false` for "automerge is off".
- Never put `commitMessage*` at the top level and assume it applies — manager
  defaults win.
- Never document a rule with a comment when it takes a `description`.
- In a repo with `.github/release.yaml`, never let a bot PR go in without
  the changelog-category label its release notes sort on.
- Never patch lockstep bot PRs one by one — bump the family together and add
  the group in the same PR.
