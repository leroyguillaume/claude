---
name: argocd-conventions
description: Argo CD GitOps repository conventions — the repository shape
  (catalog-driven ApplicationSets over Argo CD's own cluster list, three
  values layers) applies only when bootstrapping or when explicitly asked to
  refactor; in an existing repo, follow the shape that is already there. The
  object-level rules always apply: OCI chart references pinned to an exact
  latest version, `revisionHistoryLimit: 0` everywhere, AppProject
  `sourceRepos` as an allowlist.
  TRIGGER when: creating or editing an `Application`, `ApplicationSet`,
  `AppProject`, or any file in a GitOps/deployment repository that Argo CD
  reads; adding an app or a cluster to such a repo; bumping a chart version;
  user asks about Argo CD, ApplicationSets, GitOps layout, chart sources, sync
  policy, or sync waves.
  SKIP when: authoring the Helm chart itself (that is `helm-conventions`), or
  working on Kubernetes manifests with no Argo CD involvement.
---

# Argo CD conventions

For a repository whose job is to deploy a set of applications onto a set of
clusters.

## Read this first: when the layout applies

**The repository shape described below is for a repo you are creating, not a
verdict on one that already exists.** Two modes:

- **Bootstrapping a new GitOps repository, or explicitly asked to refactor an
  existing one to these conventions** — use the layout below in full. Deviate
  only with a reason written down in `ARCHITECTURE.md`.
- **Working in a repository that is already laid out some other way** — use
  *its* layout. Read how it does things and match it: its directory names, its
  templating (plain YAML, Kustomize, Helm-of-Helms, an `Application` per app
  hand-written), where values live, how a cluster is onboarded.

**In that second mode, do not challenge the structure.** Not in a comment, not
in a "note that this would be cleaner as…", not by quietly introducing a
`lib/` beside the existing files. A GitOps layout is load-bearing for people
and pipelines you cannot see, and a repo that is half one shape and half
another is worse than either. The user knows this skill exists; if they want
the refactor they will ask for it.

**What still applies in both modes** is everything below that is a property of
a single object rather than of the repository: `revisionHistoryLimit: 0`, OCI
chart references, exact version pins resolved from the actual latest, no globs
in `sourceRepos`, `RespectIgnoreDifferences` beside an `ignoreDifferences`,
retry rather than cross-app sync waves. Apply those to what you write, in the
local idiom — do not sweep the repo to retrofit them, and if an existing
choice is a genuine correctness problem, say it once, plainly, then let it go.

## The model: one list, not two

**Argo CD's own cluster list is the deployment target list.** Register a
cluster and every app in the catalog lands on it; unregister it and nothing in
the repository mentions it. No per-cluster branch, no `envs/` matrix, no
second inventory to keep in step — a list that has to be kept in step is a
list that eventually is not.

Apps are **enabled by default and disabled by exception**: a label on the
cluster's Argo CD Secret takes one app off one cluster, and the selector uses
`NotIn` so that a cluster carrying no label at all matches. Adding a cluster
is then a registration, not a sweep through every app.

## Layout

```
apps/
  root.yaml                      # bootstrap Application, applied once by hand
  catalog.libsonnet              # what each app IS — chart, namespace, options
  appsets.jsonnet                # one ApplicationSet per catalog entry
  projects.jsonnet               # the AppProject, derived from the catalog
  <app>/<app>.yaml               # default Helm values, every cluster
  <app>/resources/*.jsonnet      # default extra manifests
clusters/
  _sample/                       # onboarding reference, rendered like a cluster
  <cluster>/<cluster>.yaml       # cluster-level values, under one `config:` root
  <cluster>/<app>/<app>.yaml     # per-cluster Helm value deltas
  <cluster>/<app>/resources/*.jsonnet
lib/                             # shared jsonnet libraries
rendered/                        # `make render` output, reviewed not applied
```

Three layers, and the boundary between them is what keeps the repo readable:

1. **The catalog** — what an app *is*. Same on every cluster.
2. **`apps/<app>/`** — what an app looks like *by default*, everywhere.
3. **`clusters/<cluster>/`** — what *this* cluster does differently, and
   nothing else. A cluster file that restates a default is drift waiting to
   happen; delete the line.

**A generic ApplicationSet template lives in `lib/`, not copy-pasted per app.**
One app is one catalog entry, not one hand-written `ApplicationSet`.

## The catalog

One entry per app, carrying what the ApplicationSet template cannot infer:

- `chart` — `repoURL`, `name`, `version` (see the two chart rules below).
- `namespace` — where it lands.
- `syncOptions` — optional, appended to the template's defaults.
- `helmParameters` — optional, and the *only* place a value may depend on the
  cluster, since these strings are rendered by the ApplicationSet. A parameter
  beats every values file, so this is for what a cluster must not be able to
  get wrong, never for a default it might want to override.
- `ignoreDifferences` — optional, for a field another controller in the
  cluster owns and rewrites.

Everything else derives from the catalog rather than being restated: the
`ApplicationSet` list, the `AppProject`'s `sourceRepos`. **Adding a chart
repository must be a one-line change in one file**, or the two copies drift.

## Charts: OCI first

**Reference charts as OCI artefacts.** An OCI registry is one artefact store
for charts and images, with one credential, one mirroring story and immutable
digests — an HTTP chart repository is a second protocol, a second credential
and an `index.yaml` that gets regenerated under you.

- **Write the `repoURL` with no scheme**: `ghcr.io/<org>/charts`, never
  `oci://ghcr.io/…`. That is how Argo CD tells an OCI registry from an HTTP
  chart repository — it parses the URL and finds no host. (`oci://` is the
  `helm` CLI's form, not the `Application`'s.)
- The repository credential in Argo CD is `type: helm` with `enableOCI: true`.
- **An HTTP chart repository is a documented exception**, not a fallback:
  when upstream publishes no OCI chart at all. State in `ARCHITECTURE.md` what
  has to exist for the line to become an OCI reference, so the exception is
  tracked rather than permanent.
- **Mirrored registries**: keep the *registry* in the cluster's values file
  and the *path* in the catalog, then build the reference from the two. The
  path is a fact about the chart, the registry a fact about where the cluster
  can reach. A registry that varies per cluster and is written once per chart
  is the wrong way round.

## Chart versions: the latest, pinned exactly

Two rules that sound opposed and are not — freshness is a property of the
moment you edit the catalog, never a runtime behaviour.

- **Always resolve the actual latest version before writing one.** Never a
  version from memory, never "bump the patch and hope". Look it up:

  ```bash
  helm show chart oci://<registry>/<path>/<chart> | grep '^version:'
  ```

  ```bash
  helm repo add <name> <url> && helm repo update && helm search repo <name>/<chart> --versions | head
  ```

  Read the upstream release notes before bumping a major, and say in the PR
  what changed. A chart version is not a dependency bump like any other: it is
  a change to every cluster at once.
- **Pin the exact version. Never a range.** Argo CD *does* accept a semver
  constraint in `targetRevision` (`~1.2.0`, `*`), and that is precisely the
  trap: the deployed version stops being in git, two clusters synced a week
  apart run different code, and a rollback is no longer a revert. If the
  version is not in the diff, nobody reviewed it.
- **Keep "latest" true over time with a bot, not a range** — Renovate (a
  custom manager over the catalog, or its `argocd` manager over plain
  `Application` YAML). A bumped pin arrives as a reviewable PR, which is the
  whole difference.

## The generated Application

### `revisionHistoryLimit: 0`, on every Application

**Always. No exceptions, the bootstrap root app included.** Argo CD keeps the
last ten syncs in `status.history` by default, and an entry there is not a
line: it carries the fully resolved source list, chart version and revision
included. That payload grows with how often an app is synced, on an object the
ApplicationSet controller rewrites on every reconcile.

What it costs is `argocd app rollback` and `argocd app history`, and that is
the right trade: **git is the record of what was deployed**, so a rollback is
a revert and a sync. Read the commit log, not the cluster.

(The chart-level `revisionHistoryLimit` — the one that caps ReplicaSets — is a
separate knob, set in the app's values file. Same reasoning, same answer.)

### Multi-source: chart plus values from this repo

Four sources, in this order:

1. **The upstream chart** — `repoURL` + `chart` + `targetRevision`, with
   `helm.valueFiles` pointing into the repo via `$values`, most specific last:
   `$values/apps/<app>/<app>.yaml`, then
   `$values/clusters/<cluster>/<app>/<app>.yaml`.
2. **The `$values` ref** — this repository, `ref: values`, **no `path`**. With
   a path it would contribute manifests as well as values.
3. **Default extra manifests** — `apps/<app>/resources/`.
4. **Per-cluster extra manifests** — these *concatenate* with the defaults,
   they do not override them.

Two traps worth knowing before you hit them:

- **`ignoreMissingValueFiles: true`** is required, because most clusters
  override nothing and most of those files do not exist. It also hides typos
  in those paths — which is what the render check exists for.
- **Argo CD fails an Application whose source `path` does not exist.** For the
  per-cluster source, point `path` at a directory that always exists
  (`clusters`) and narrow with `directory.include`; matching nothing is legal
  and empty, missing is fatal.

### Generators

A **matrix** over Argo CD's cluster list and the cluster's own values file.
Order is load-bearing, not stylistic: the generator that *consumes* a
parameter comes after the one that produces it, so the clusters generator
comes first and the git generator interpolates the cluster name.

- **`goTemplate: true` with `goTemplateOptions: ['missingkey=error']`.** A
  missing key must fail the render, not resolve to empty and deploy something
  plausible.
- **A matrix is a cartesian product**: a cluster with no values file produces
  no parameters and therefore no Application — on every app at once, silently.
  Assert in CI that every directory under `clusters/` has its file.
- **`syncPolicy.applicationsSync: create-update`.** Disabling an app or
  unregistering a cluster then orphans the `Application` instead of deleting
  it, and with it the workloads. Removal stays a deliberate
  `argocd app delete`.
- Name the Application from `{{ .nameNormalized }}`, not `{{ .name }}` — a
  cluster name is free text, an object name is not.

### Passing cluster config into jsonnet

One `extVar` carrying the whole config object as JSON (`{{ toJson .config }}`),
decoded with `std.parseJson`, rather than one extVar per key. It scales to any
schema without adding a goTemplate expression, and the set of expressions that
can reach a rendered Application stays small enough to reproduce offline.

**Pass it as a plain string, never `code: true`** — `code` evaluates the value
as jsonnet, which turns a values file into an execution channel for nothing.

### Sync policy

- `CreateNamespace=true` with `managedNamespaceMetadata` for the labels other
  controllers select the namespace by. **Two Applications sharing a namespace
  must write the same metadata**, or they take turns rewriting each other's
  labels on every sync, forever.
- `ServerSideApply=true` when the chart's CRDs are past the 262144-byte
  annotation limit a client-side apply has to live with — most CRD-heavy
  charts are. Not a blanket default: set it where it is needed and say why.
- `RespectIgnoreDifferences=true` alongside any `ignoreDifferences`. Without
  it the ignore silences the *report* only: every sync still pushes the field,
  the other controller rewrites it, and the two managers fight forever.
- **Automated sync is a deliberate choice, stated either way.** Whichever you
  pick, write it in `ARCHITECTURE.md` — including that self-heal goes with it,
  so a cluster patched by hand keeps the patch until the next sync.

## Ordering

**Sync waves order resources inside one Application. They do nothing between
Applications** — two generated by different ApplicationSets have no ordering
relationship at all, whatever their waves say.

Cross-app ordering is **convergence by retry**: a resource that lands before
its CRD fails, backs off, and succeeds within the same sync operation. Give
every Application a retry policy with real headroom rather than trying to
sequence apps:

```yaml
retry:
  limit: 10
  backoff:
    duration: 15s
    factor: 2
    maxDuration: 5m
```

## The AppProject

- **`sourceRepos` is an allowlist — list the registries, never glob them.**
  `*/org/charts` permits that path under *any* host in the world, so a typo in
  a cluster's registry pulls a chart from wherever the typo resolves and
  reports nothing. Listed, the same typo is an Application Argo CD refuses by
  name.
- Derive it from the catalog so adding a chart repository stays one line in
  one file.
- Create it **before** the ApplicationSets that reference it — a sync wave on
  the AppProject, inside the root app's own sync, is a wave that does
  something.

## The bootstrap root app

One `Application`, applied once by hand, that renders the directory it lives
in — so a change to it goes out with a sync rather than waiting for somebody
to remember the command.

- **`directory.recurse: false`**, or it treats every values file under `apps/`
  as a manifest.
- **`argocd.argoproj.io/sync-options: Prune=false` on the root itself.** A
  rename or a bad merge that removes this file is otherwise a root app that
  prunes itself out of existence, taking the AppProject and every
  ApplicationSet with it via the finalizer.
- It runs in the `default` project: the AppProject it would otherwise use is
  generated by this very app, so it cannot be its own prerequisite.
- `in-cluster` is named **here and nowhere else** — it is applied before any
  cluster Secret exists, and Argo CD resolves that name from a built-in
  special case.

## Cluster values files

- **Everything under one `config:` root.** The git generator prefixes `path.*`
  and nothing else — a file's own top-level keys land in the same parameter
  set as the clusters generator's, so a bare `name:`, `server:` or
  `metadata:` would shadow Argo CD's own.
- **Only what varies per cluster** *and* is actually read. A one-off literal
  inside a plain manifest stays where it is.
- **Keep a `_sample` cluster** as the onboarding reference, with values that
  are obviously dead (`.invalid` hostnames, zero UUIDs) so a copied file with
  a line left unchanged fails loudly instead of pointing somewhere plausible.
  Render it like a real cluster in CI — that is what stops it rotting into a
  description of a repository that no longer exists.
- The values file's name must match its directory: it is the lookup
  (`clusters/{{ .name }}/{{ .name }}.yaml`), not a convention. Assert it in
  CI, because Argo CD will not — it just generates nothing.

## Render before you merge

**Render every (cluster, app) pair into `rendered/` and review the diff.**
A `make render` / `make validate` pair, run in CI, is what turns "the template
looks right" into "this is the manifest that will land". It catches the
failure modes above that Argo CD reports as silence: the missing cluster file,
the values path typo hidden by `ignoreMissingValueFiles`, the goTemplate
expression nothing resolves.

`rendered/` is committed and reviewed, never applied.

**Never:**

- Never write an `Application` without `revisionHistoryLimit: 0`.
- Never use a semver range in `targetRevision`, and never write a chart
  version from memory instead of looking up the latest.
- Never prefix an OCI chart `repoURL` with `oci://` in an `Application`.
- Never hand-write one `ApplicationSet` per app — the template lives in `lib/`
  and the difference lives in the catalog.
- Never glob an entry in `sourceRepos`.
- Never give the `$values` source a `path`, and never point a source `path` at
  a directory that may not exist.
- Never rely on sync waves to order one Application against another.
- Never restate a default in a cluster file just to be explicit.
