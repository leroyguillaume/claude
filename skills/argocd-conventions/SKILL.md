---
name: argocd-conventions
description: >-
  Argo CD object conventions, true in any GitOps repository whatever its
  layout — OCI chart references pinned to an exact latest version,
  `revisionHistoryLimit: 0` everywhere, no automated sync, retry rather than
  cross-app sync waves, AppProject `sourceRepos` as an allowlist, and the
  ApplicationSet generator traps. A new GitOps repository, or one being
  refactored, follows the latest release of THEREALM ALS (THEREALM ArgoCD
  Layout Specification).
  TRIGGER when: creating or editing an `Application`, `ApplicationSet`,
  `AppProject`, or any file in a GitOps/deployment repository that Argo CD
  reads; bootstrapping such a repository or adding a project, app or cluster
  to one; bumping a chart version; user asks about Argo CD, ApplicationSets,
  generators, chart sources, sync policy, sync waves, or how a GitOps
  repository is laid out.
  SKIP when: authoring the Helm chart itself (that is `helm-conventions`), or
  working on Kubernetes manifests with no Argo CD involvement.
---

# Argo CD conventions

Rules about a single Argo CD object, which hold whatever shape the repository
has.

## Repository layout: THEREALM ALS, latest release

**How a GitOps repository is laid out — projects, catalogs, directories,
which app lands where, what CI checks — is the
[THEREALM ArgoCD Layout Specification](https://github.com/therealm-tech/argocd-layout-spec)
(THEREALM ALS).** Follow its latest release, never `main` and never what you
remember of it. Releases are named `YYYYMMDD-N`:

```bash
gh release view --repo therealm-tech/argocd-layout-spec --json tagName --jq .tagName
```

Then read `SPEC.md` at that tag before writing anything:

```text
https://raw.githubusercontent.com/therealm-tech/argocd-layout-spec/<tag>/SPEC.md
```

- **Bootstrapping a GitOps repository, or explicitly asked to refactor one**:
  conform to the spec in full, and record the release conformed to in the
  repository's `README.md`, as the spec's §1 requires.
- **A repository that already cites a version**: follow *that* version. Moving
  it to a newer one is a refactor, done when asked, one version's changes at a
  time.
- **A repository laid out some other way**: use *its* layout — its directory
  names, its templating, where its values live, how it onboards a cluster and
  switches an app on. Do not challenge the structure: not in a comment, not in
  a "this would be cleaner as…", not by quietly adding a `lib/`. A layout is
  load-bearing for people and pipelines you cannot see, and a repository that
  is half one shape and half another is worse than either. If the user wants
  the refactor, they will ask.

The rules below hold in all three cases. **In a repository laid out some other
way, apply them to what you write, in the local idiom.** Do not sweep the repo
to retrofit them, and if an existing choice is a genuine correctness problem,
say it once, plainly, then let it go.

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
- **Mirrored registries**: keep the *registry* in the cluster's values and the
  *path* beside the chart, then build the reference from the two. The path is
  a fact about the chart, the registry a fact about where the cluster can
  reach. A registry that varies per cluster and is written once per chart is
  the wrong way round.

## Chart versions: the latest, pinned exactly

Two rules that sound opposed and are not — freshness is a property of the
moment you edit the version, never a runtime behaviour.

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
  custom manager over wherever versions live, or its `argocd` manager over
  plain `Application` YAML). A bumped pin arrives as a reviewable PR, which is
  the whole difference.

## The Application

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

### Sources

- **A `$values` ref source takes no `path`.** With one it contributes
  manifests as well as values.
- **Argo CD fails an Application whose source `path` does not exist.** For a
  directory that may be absent, point `path` at a parent that always exists
  and narrow with `directory.include`; matching nothing is legal and empty,
  missing is fatal.
- **`ignoreMissingValueFiles: true`** is what lets an optional values file be
  optional — and it hides typos in those paths, which is what a render check
  exists for.
- **`directory.include` and `exclude` globs have no path separator**: they
  match the path relative to the source's `path`, and `*` crosses `/`. So
  `*/*.yaml` matches `a/b/c.yaml` too; bound the depth with an `exclude`
  (`*/*/*` keeps only files one directory down).

### Passing values into jsonnet

One `extVar` carrying a whole config object as JSON (`{{ toJson .config }}`),
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

### No automated sync

**No `automated` block. An app syncs when somebody asks it to.**

Rendering stays continuous — a commit lands, Argo CD reports the app
`OutOfSync`, and the diff is there to read. *Applying* is the deliberate half.
It is the same argument as never automerging a dependency PR: a commit that
reaches every cluster without anyone pressing anything is a change to
production nobody read, and a green render is not a review — it proves the
manifests are valid, not that they are wanted.

State the cost rather than hiding it:

- **Self-heal goes with it.** A cluster patched by hand keeps the patch until
  the next sync, so drift is real and stays until someone syncs. That is the
  trade: drift you can see beats a change you did not.
- **Pruning goes with it too**, so a resource removed from git stays in the
  cluster until a sync with pruning on. Removal is deliberate, like everything
  else here.
- A sync that exhausts its retries is re-run by hand.

Turning it back on is one block, in the ApplicationSet template — say so in
`ARCHITECTURE.md` so nobody has to find it:

```yaml
automated:
  prune: true
  selfHeal: true
```

**The one exception is a repo that already runs on automated sync.** There,
a single Application without it silently never deploys — the worst failure
mode in the list. Match the repo and say once that it is off-convention.

## ApplicationSets

- **`goTemplate: true` with `goTemplateOptions: ['missingkey=error']`.** A
  missing key must fail the render, not resolve to empty and deploy something
  plausible.
- **A matrix is a cartesian product, and it is silent.** A child that yields
  nothing for one parameter set generates no Application there and reports
  nothing. Whatever a matrix reads, assert in CI that it exists where it must.
- **A matrix combines exactly two children and nests one level deep.** Three
  generators are `matrix(matrix(a, b), c)`, and there is no room for a fourth.
  A child *consuming* a parameter comes after the one producing it.
- **A `pathParamPrefix` on every git generator in a matrix**, or their
  `path.*` parameters collide. Top-level keys of a file the git generator reads
  are never prefixed: keep them under one root (`config:`), or a bare `name:`
  or `metadata:` shadows the clusters generator's own.
- **Give the clusters generator a selector.** With none, Argo CD adds a
  synthesised `in-cluster` entry that carries no `.metadata.labels`, which
  trips `missingkey=error` on any template reading them.
  `matchLabels: {argocd.argoproj.io/secret-type: cluster}` names what every
  cluster Secret carries and nothing else.
- **`syncPolicy.applicationsSync: create-update`.** An Application that stops
  being generated is then orphaned instead of deleted, and its workloads with
  it. Removal stays a deliberate `argocd app delete`.
- Name the Application from `{{ .nameNormalized }}`, not `{{ .name }}` — a
  cluster name is free text, an object name is not.

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
- Create it **before** the ApplicationSets that reference it — a sync wave on
  the AppProject, inside the root app's own sync, is a wave that does
  something.

## The bootstrap root app

One `Application`, applied once by hand, that renders the directory it lives
in — so a change to it goes out with a sync rather than waiting for somebody
to remember the command.

- **It renders only manifests**: `directory.recurse: false`, or a recursive
  source whose `include` / `exclude` pin exactly the files it owns — anything
  else treats every values file below it as a manifest.
- **`argocd.argoproj.io/sync-options: Prune=false` on the root itself.** A
  rename or a bad merge that removes this file is otherwise a root app that
  prunes itself out of existence, taking the AppProject and every
  ApplicationSet with it via the finalizer.
- It runs in the `default` project: an AppProject it generates cannot be its
  own prerequisite.
- `in-cluster` is named **here and nowhere else** — it is applied before any
  cluster Secret exists, and Argo CD resolves that name from a built-in
  special case.

**Never:**

- Never write an `Application` without `revisionHistoryLimit: 0`.
- Never use a semver range in `targetRevision`, and never write a chart
  version from memory instead of looking up the latest.
- Never prefix an OCI chart `repoURL` with `oci://` in an `Application`.
- Never glob an entry in `sourceRepos`.
- Never give the `$values` source a `path`, and never point a source `path` at
  a directory that may not exist.
- Never rely on sync waves to order one Application against another.
- Never add an `automated` sync block — nor reach for it to work around an app
  somebody keeps forgetting to sync.
