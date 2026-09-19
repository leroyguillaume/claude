---
name: argocd-layout-conventions
description: >-
  Argo CD GitOps repository layout — a catalog of apps turned into one
  ApplicationSet each, over Argo CD's own cluster list, where an app runs on a
  cluster when `clusters/<cluster>/<app>/` exists; three values layers, a
  README per app, cluster and (cluster, app) directory, a rendered sample
  cluster. Applies only when bootstrapping a GitOps repository or when
  explicitly asked to refactor one; in an existing repo, follow the shape
  already there. The object-level rules are `argocd-conventions`.
  TRIGGER when: bootstrapping a GitOps/deployment repository; adding an app or
  a cluster to one laid out this way; putting an app on or taking it off a
  cluster; writing or restructuring the READMEs of such a repo; user asks how
  such a repository is laid out, where values live, or how an app is enabled
  per cluster.
  SKIP when: editing one Argo CD object with no layout question (that is
  `argocd-conventions`), or working in a GitOps repository laid out another
  way and nobody asked to change it.
---

# Argo CD repository layout

For a repository whose job is to deploy a set of applications onto a set of
clusters. Every object in it also follows `argocd-conventions`.

## Read this first: when the layout applies

**The shape described below is for a repo you are creating, not a verdict on
one that already exists.** Two modes:

- **Bootstrapping a new GitOps repository, or explicitly asked to refactor an
  existing one to these conventions** — use the layout below in full. Deviate
  only with a reason written down in `ARCHITECTURE.md`.
- **Working in a repository that is already laid out some other way** — use
  *its* layout. Read how it does things and match it: its directory names, its
  templating (plain YAML, Kustomize, Helm-of-Helms, an `Application` per app
  hand-written), where values live, how a cluster is onboarded, how an app is
  switched on or off.

**In that second mode, do not challenge the structure.** Not in a comment, not
in a "note that this would be cleaner as…", not by quietly introducing a
`lib/` beside the existing files. A GitOps layout is load-bearing for people
and pipelines you cannot see, and a repo that is half one shape and half
another is worse than either. The user knows this skill exists; if they want
the refactor they will ask for it. Only the [READMEs](#readmes) carry over:
another layout's per-app and per-environment directories get the same
treatment.

## The model: the cluster list, and a directory per app

**Argo CD's own cluster list is the deployment target list.** Register a
cluster and it exists; unregister it and nothing in the repository deploys to
it. No per-cluster branch, no `envs/` matrix, no second inventory of clusters
to keep in step — a list that has to be kept in step is a list that eventually
is not.

**An app runs on a cluster when `clusters/<cluster>/<app>/` exists.** That
directory already holds the pair's README and overrides, so what runs where is
`ls clusters/<cluster>/` — the place a reader looks for everything else about
the pair — and not a label on the cluster Secret. Taking an app off is
deleting its directory; adding a cluster is copying `_sample/`, which holds a
directory per app, and deleting what it does not run.

## Layout

```
apps/
  README.md                      # the four files below, and the one list of apps
  root.yaml                      # bootstrap Application, applied once by hand
  catalog.libsonnet              # what each app IS — chart, namespace, options
  appsets.jsonnet                # one ApplicationSet per catalog entry
  projects.jsonnet               # the AppProject, derived from the catalog
  <app>/README.md                # what the app does, on every cluster
  <app>/<app>.yaml               # default Helm values, every cluster
  <app>/resources/*.jsonnet      # default extra manifests
clusters/
  README.md                      # the one list of clusters
  _sample/_sample.yaml           # onboarding reference, rendered like a cluster
  _sample/<app>/.gitkeep         # one per catalog app — git tracks no empty directory
  <cluster>/README.md            # the cluster as a whole, and why an app is absent
  <cluster>/BOOTSTRAP.md         # its full bootstrap, with its real names
  <cluster>/<cluster>.yaml       # cluster-level values, under one `config:` root
  <cluster>/<app>/README.md      # what this app does differently here
  <cluster>/<app>/<app>.yaml     # per-cluster Helm value deltas
  <cluster>/<app>/resources/*.jsonnet
lib/                             # shared jsonnet libraries
  <bucket>/README.md             # what the libraries in it build, and for whom
rendered/                        # `make render` output, reviewed not applied
```

Three layers, and the boundary between them is what keeps the repo readable:

1. **The catalog** — what an app *is*. Same on every cluster.
2. **`apps/<app>/`** — what an app looks like *by default*, wherever it runs.
3. **`clusters/<cluster>/`** — which apps *this* cluster runs, what it does
   differently, and nothing else. A cluster file that restates a default is
   drift waiting to happen; delete the line.

**A generic ApplicationSet template lives in `lib/`, not copy-pasted per app.**
One app is one catalog entry, not one hand-written `ApplicationSet`.

## READMEs

**Every app, cluster and (cluster, app) directory has a `README.md`**, so a fact
sits next to the config that produces it. Load `documentation-conventions`
first: this layout must stay true without an LLM.

| README | Says | Never says |
| --- | --- | --- |
| `apps/` | what the four top-level files do; the **one** list of apps, a line each on what it *is* | versions, namespaces — the catalog's |
| `apps/<app>/` | what the app does, and what is unusual about how it is deployed | which clusters run it, an inventory of its files |
| `clusters/` | the **one** list of clusters, where each runs, its infra repo | per-cluster details |
| `clusters/<cluster>/` | the cluster as a whole: access, secret backend, DNS, TLS, databases, network; why each catalog app it does not run is absent | the apps it runs — its directories say so |
| `clusters/<cluster>/<app>/` | what this app does differently here, and why | the defaults, restated |
| `lib/<bucket>/` | what the libraries build, who calls them | the overall design |

- **`_sample/` gets none of these**: it is not a cluster, and holds its values
  file and one `.gitkeep`'d directory per catalog app — no README, no
  `BOOTSTRAP.md`.
- **Every app a cluster runs gets its per-cluster README**, even with no
  override (one line saying so). Argo CD ignores them: directory sources skip
  `.md`.
- **An absent app has no directory to explain itself**, so the cluster's
  README says why, one short section per absent app. The absences only: the
  apps it runs are its directories, and restating them is a list that drifts.
- **Point with a pattern, never a list**: "what a cluster does differently is in
  `clusters/<cluster>/<app>/README.md`". Adding a cluster touches no app README;
  adding an app touches no cluster README it does not run on.
- **Each cluster's bootstrap lives whole in `clusters/<cluster>/BOOTSTRAP.md`**,
  with its real names — it is that cluster's procedure and changes with it, and
  out of the README it keeps both files readable. Why a step exists at all goes
  once in `ARCHITECTURE.md`.
- **No deployment state**: never whether a stack is applied or an app synced.
- **A root `lib/README.md` only if the validator allows a file there**;
  otherwise `ARCHITECTURE.md`'s bucket table is the index.
- **Comments pointing at a README section move with it.**

## The catalog

One entry per app, carrying what the ApplicationSet template cannot infer:

- `chart` — `repoURL` (the mirror path; the registry comes from the cluster),
  `name`, `version`.
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

## The generated Application

### Generators

Argo CD's cluster list, crossed with the cluster's values file, crossed with
the app's directory on that cluster:

```yaml
generators:
  - matrix:
      generators:
        - matrix:
            generators:
              - clusters:
                  selector:
                    matchLabels:
                      argocd.argoproj.io/secret-type: cluster
              - git:
                  pathParamPrefix: clusterConfig
                  files:
                    - path: clusters/{{ .name }}/{{ .name }}.yaml
        - git:
            pathParamPrefix: appDirectory
            directories:
              - path: clusters/{{ .name }}/<app>
```

- **The directories generator is the switch**: no directory, no parameters, no
  Application. Git tracks no empty directory, which is why `_sample/`'s hold a
  `.gitkeep` and a real cluster's hold at least their README.
- **A cluster with no values file generates nothing, on every app at once**,
  and a misspelt app directory is an app silently not deployed. Assert in CI
  that every directory under `clusters/` has its file, that every directory
  inside a cluster's is named after an app, and that `_sample/` generates
  every app.
- **Taking an app off orphans its Application** (`create-update`), so the
  workloads keep running until a deliberate `argocd app delete`. Deleting a
  directory is one commit; deleting a database is not.

### Four sources, in this order

1. **The upstream chart** — `repoURL` + `chart` + `targetRevision`, with
   `helm.valueFiles` pointing into the repo via `$values`, most specific last:
   `$values/apps/<app>/<app>.yaml`, then
   `$values/clusters/<cluster>/<app>/<app>.yaml`, with
   `ignoreMissingValueFiles: true` since most clusters override nothing.
2. **The `$values` ref** — this repository, `ref: values`, no `path`.
3. **Default extra manifests** — `apps/<app>/resources/`, which therefore has
   to exist, even empty.
4. **Per-cluster extra manifests** — `path: clusters` narrowed with
   `include: <cluster>/<app>/resources/*`, because most apps have no
   `resources/` on most clusters and a missing path is fatal. These
   *concatenate* with the defaults, they do not override them.

## Cluster values files

- **Everything under one `config:` root**, passed to jsonnet as one extVar.
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
failure modes Argo CD reports as silence: the missing cluster file, the
misspelt app directory, the values path typo hidden by
`ignoreMissingValueFiles`, the goTemplate expression nothing resolves.

`rendered/` is committed and reviewed, never applied.

**Never:**

- Never hand-write one `ApplicationSet` per app — the template lives in `lib/`
  and the difference lives in the catalog.
- Never restate a default in a cluster file just to be explicit.
- Never leave an app or a cluster directory without its `README.md`, and never
  skip a per-cluster app README because the app has no override.
- Never keep a directory for an app a cluster does not run, not even as
  dormant configuration — the directory is what deploys it.
- Never switch an app on or off per cluster with a label on the cluster
  Secret: the directory is the one switch.
- Never list clusters in an app README, or the apps a cluster runs in its
  README — link the pattern, and keep the one list of each in
  `apps/README.md` and `clusters/README.md`.
