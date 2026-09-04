---
name: renovate-conventions
description: >-
  Dependency-update bot conventions — on GitHub, Dependabot for
  everything it supports and Renovate only for the remainder (never both on
  one ecosystem); off GitHub, Renovate for the lot. Never automerge, ever.
  Dependency dashboard always on.
  TRIGGER when: creating or editing `renovate.json`/`.json5`/`.renovaterc`,
  a `renovate` key in `package.json`, or `.github/dependabot.yml`/`.yaml`;
  setting up automated dependency updates for a repo; adding a custom/regex
  manager for a version string no manager knows; user asks about Renovate,
  Dependabot, dependency PRs, grouping or update scheduling.
  SKIP when: bumping a dependency by hand with no bot configuration involved.
---

# Renovate / Dependabot conventions

## On GitHub, Dependabot first

**Use Dependabot for every ecosystem it supports. Reach for Renovate only for
what it does not cover.** It is built into the platform: no app to install, no
token to rotate, no self-hosted runner, and its findings sit next to the
security alerts for the same repository. A second bot is a second thing to
configure, debug and explain.

- **Check what Dependabot supports today rather than assuming.** The list
  grows — read
  <https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories>
  before concluding that something needs Renovate. Answering from memory is
  how a repo ends up running two bots for one job.
- **What Renovate is actually for**, once Dependabot has taken its share:
  - a version string **no manager knows about** — a chart version inside a
    jsonnet or YAML catalog, a pinned tool version in a `Makefile`, a CI
    script or a `Dockerfile` `ARG`. That is a custom manager, and Dependabot
    has no equivalent.
  - grouping or scheduling rules Dependabot cannot express.
- **Off GitHub — GitLab, Gitea, self-hosted — Renovate does the whole job.**
  There is no Dependabot to prefer.
- **"Dependabot first" is not "Dependabot for as much as possible".** In a repo
  where Renovate is already required for the bulk — a GitOps repo, where the
  `argocd`, `helm-values` and `crossplane` managers see chart and image
  versions Dependabot has no manager for — handing it back one ecosystem it
  covers coherently buys nothing and splits one review flow in two. The stable
  split there is **`github-actions` to Dependabot, everything else to
  Renovate**: Dependabot handles SHA pins and their trailing tag comments
  natively, which is the one thing worth keeping it for.

**Never point both bots at the same ecosystem or the same file.** Two PRs for
one bump, two lockfile updates that conflict with each other, and reviewers
who learn to skim. Make the split explicit rather than implicit: give Renovate
an `enabledManagers` list covering only what Dependabot does not, and say in
`ARCHITECTURE.md` where the line is drawn.

Two ways to draw it, and they are not equivalent:

```json5
{
  // Allowlist. Dependabot owns cargo, docker and github-actions; Renovate is
  // here only for the chart versions in the catalog, which no Dependabot
  // ecosystem can see.
  enabledManagers: ["custom.regex"],
}
```

```json
{
  "github-actions": { "enabled": false }
}
```

The **allowlist** is the safer default when Dependabot owns several ecosystems:
a manager Renovate gains in a future release cannot start racing. The
**blocklist** is right when Renovate owns everything but one — turning off the
single overlapping manager states exactly that, and an allowlist would need
editing every time the repo grows a new file type.

## Never automerge

**No automerge, in any form.** Not `automerge: true`, not an automerge preset
(`:automergeMinor`, `:automergeDigest`, …), not `platformAutomerge`, not
`@dependabot merge`, and not a workflow that runs `gh pr merge --auto` on a
bot PR.

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
- **group what must move together**, which is a different reason and the one
  that prevents breakage rather than noise: two charts version-locked
  upstream, or the chart and the CRD set that are two sources of one
  `Application`. Split across two PRs, one of them merges alone and the
  cluster is briefly in a combination nobody tested. Match by file
  (`matchFileNames`) when the second dependency's `depName` is a git URL
  rather than a chart name;
- `minimumReleaseAge` (Renovate) / `cooldown` (Dependabot) so a release has to
  survive a few days in the wild before it is proposed;
- `prConcurrentLimit` / `open-pull-requests-limit` so the queue stays a queue
  and not a wall.

## Dependency dashboard on

**`dependencyDashboard: true`, always.** It is the only place that shows what
Renovate decided *not* to open a PR for — rate-limited, blocked by a failed
lookup, awaiting approval, deprecated datasource, explicitly ignored.

Without it, **silence is ambiguous**: no PR for three months reads as "nothing
to update" and means "the manager stopped matching after a refactor" just as
often. The dashboard is what turns that into a visible list.

```json5
{
  dependencyDashboard: true,
  dependencyDashboardTitle: "Dependency dashboard",
  dependencyDashboardLabels: ["dependencies"],
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
- **Dependabot has no equivalent.** Its config failures surface only in the
  repository's Dependabot run logs, so a broken `dependabot.yaml` is quiet in
  a way Renovate is not — check the last run after changing it.

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

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  extends: ["config:recommended"],
  timezone: "Europe/Paris",
  dependencyDashboard: true,
  labels: ["dependencies"],
  prConcurrentLimit: 5,
  minimumReleaseAge: "3 days",
}
```

- **`labels` must include the repo's changelog-category label** so bot PRs
  land in the right release-notes section — see `github-pr-conventions`, and
  read the repo's actual labels rather than inventing one.
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
  updates away** — leave `vulnerabilityAlerts` unrestricted.

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

The reason Renovate is there at all, usually. Each one needs a comment saying
which file it matches and what the line looks like — a regex over someone
else's format is unreadable six months later:

```json5
{
  customManagers: [
    {
      // Chart versions in the app catalog:
      //     version: '1.2.3',  // renovate: datasource=docker depName=…
      customType: "regex",
      managerFilePatterns: ["/^apps/catalog\\.libsonnet$/"],
      matchStrings: ["datasource=(?<datasource>\\S+) depName=(?<depName>\\S+)\\s+version: '(?<currentValue>[^']+)'"],
      versioningTemplate: "semver",
    },
  ],
}
```

**Dry-run a custom manager before merging it** (`renovate --dry-run`, or the
debug log of the next run). A regex that matches nothing fails silently — it
just never opens a PR, which looks exactly like being up to date. That is also
what the dashboard is for.

## Running Renovate

On GitHub the choice is the hosted Mend app or a self-hosted run from a
workflow. **Self-hosted keeps the config, the schedule and the logs in the
repository**, which is the same argument as everything else here; it is also
the only option that lets you dry-run on demand.

A workflow that follows `github-actions-conventions` — SHA-pinned action,
`concurrency`, least-privilege `permissions`, lowercase step names — plus two
things specific to Renovate:

- **A dedicated `RENOVATE_TOKEN`, not `GITHUB_TOKEN`.** A PR opened with
  `GITHUB_TOKEN` does not trigger other workflows, so every Renovate PR would
  arrive with no CI on it — which is exactly the check the whole review flow
  rests on. The job's own `permissions` stay `contents: read`: the token does
  the writing, not the workflow.
- **A `workflow_dispatch` `dryRun` input** wired to `RENOVATE_DRY_RUN`, and a
  `logLevel` choice input. This is what makes "dry-run a custom manager before
  merging it" a thing somebody can actually do, rather than advice.

Schedule it (`cron`) rather than running it on push: dependency updates are
not a property of a commit.

## Dependabot configuration

`.github/dependabot.yaml` (both `.yml` and `.yaml` are read). Block style
only, per `yaml-conventions`.

- **One entry per ecosystem present in the repo**, plus **`github-actions`
  always** — that is what keeps the SHA pins and their tag comments fresh
  (see `github-actions-conventions`).
- Set `labels` to the same changelog-category label as Renovate's, and
  `open-pull-requests-limit` to something a human can actually work through.
- **`groups`** for patch/minor per ecosystem; majors ungrouped.
- **`cooldown`** for the same reason as Renovate's `minimumReleaseAge`.
- **OCI registries: use a `docker-registry` entry, not `helm-registry`.** The
  Helm registry type does HTTP Basic auth against a classic chart repository
  and does not speak OCI — which is the form charts should be referenced in
  anyway (see `argocd-conventions`).

**Never:**

- Never enable automerge, in either bot, in any form — including a workflow
  that merges bot PRs for you.
- Never run both bots over the same ecosystem or the same file.
- Never turn the dependency dashboard off.
- Never add a custom manager without a comment showing the line it matches,
  and never merge one without a dry run.
- Never write a Renovate config from memory about what Dependabot supports —
  read the current list.
- Never take `platformAutomerge: false` for "automerge is off".
- Never put `commitMessage*` at the top level and assume it applies — manager
  defaults win.
- Never document a rule with a comment when it takes a `description`.
- Never let a bot PR go in without the changelog-category label the repo's
  release notes sort on.
