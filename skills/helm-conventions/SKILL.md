---
name: helm-conventions
description: Helm chart conventions (values structure, security context,
  templates layout, helm-docs, resources requests/limits).
  TRIGGER when: editing or creating any file under a chart's `templates/`,
  `values.yaml`, `values-*.yaml`, `Chart.yaml`, `.helmignore`, or a chart's
  `README.md`; adding/removing a Kubernetes object in a chart; user asks about
  Helm values, RBAC, security context, resources, or helm-docs in this repo.
  SKIP when: pure Python/Rust/Docker/CI work with no chart file touched and the
  user isn't asking about Helm.
---

# Helm chart conventions

**Always:**

- Expose `extraEnv`, `extraVolumes`, and `extraVolumeMounts` in `values.yaml`
  with empty defaults (`[]`) and wire them into every relevant workload
  template (Deployment, StatefulSet, Job, etc.).
- Define pod and container security context in `values.yaml`, defaulting to
  a **restricted** profile aligned with Kubernetes Pod Security Standards:
  ```yaml
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop: ["ALL"]
  ```
- Lay out `templates/` with **one Kubernetes object per file**, and
  derive every filename from the object's `kind` in kebab-case (split
  CamelCase on word boundaries, replace spaces with hyphens, lowercase —
  e.g. `ClusterRoleBinding` → `cluster-role-binding.yaml`,
  `MutatingWebhookConfiguration` → `mutating-webhook-configuration.yaml`).
  How files are grouped depends on how many objects a component renders:
  - A component that renders **two or more** objects gets its own
    directory `templates/<component>/` (matching its `values.yaml`
    block), with one kind-named file per object — e.g.
    `templates/api/deployment.yaml`, `templates/api/service.yaml`.
  - When a component renders **two or more objects of the same Kind**,
    nest those in a per-kind subdirectory
    `templates/<component>/<kind>/<qualifier>.yaml`. The directory carries
    the Kind, so each file is named by its distinguishing qualifier only —
    e.g. four Secrets become `templates/api/secret/database.yaml`,
    `.../jwt.yaml`, `.../oidc.yaml`, `.../bootstrap-admin.yaml`. This is
    Kind-agnostic: it applies equally to multiple Services
    (`templates/api/service/grpc.yaml`, `.../http.yaml`), ConfigMaps,
    `Job`s, etc. A Kind with a single instance in that component stays flat
    as `templates/<component>/<kind>.yaml` (one Service → `service.yaml`,
    not `service/http.yaml`).
  - A component that renders a **single** object — typically shared
    infrastructure such as an `Ingress`, a Gateway route, or a database
    `Cluster` — gets **no directory**: put the file at the root,
    `templates/<kind>.yaml` (e.g. `templates/ingress.yaml`,
    `templates/http-route.yaml`, `templates/cnpg-cluster.yaml`). Qualify
    the bare Kind with the component name when the Kind alone would be
    ambiguous (the generic `Cluster` → `cnpg-cluster.yaml`).
  Never place one component's template under another component's directory.
- Give **each component its own `ServiceAccount`** (and its own
  `ClusterRole` + `ClusterRoleBinding`, in separate files, when it needs
  cluster RBAC) so components stay least-privilege and independent.
- When a chart attaches a route to shared gateway infrastructure, create
  **only the route resource** and attach it to a **pre-existing** gateway
  referenced by name (and namespace) via `values.yaml`. This applies to
  Gateway API and Envoy (AI) Gateway: create the `MCPRoute` / `HTTPRoute` /
  `GRPCRoute`, but **never** the `Gateway` or `GatewayClass`. Make the
  gateway name **required** (`required` in the template / helper) so the
  chart fails fast when it is missing, and default the gateway namespace to
  the release namespace. The `Gateway` and `GatewayClass` are
  cluster-shared infrastructure owned outside the app chart.
- Structure `values.yaml` as exactly two kinds of top-level blocks: a
  `global:` block holding values shared by more than one component, plus
  one `<component>:` block per app/component holding that component's
  own values. As soon as a knob is needed by **two or more components**,
  it must live in `global:` at the top level — never duplicated across
  the component blocks, and never moved into one component's block
  "because that's where it's mostly used". Conversely, values used by a
  single component live only in that component's block. Every `global.*`
  key must be **overridable per component** by setting the same key in
  that component's block (resolve via a deep-merge helper:
  `mergeOverwrite (deepCopy global) (pick component …)`), so a component
  can deviate from a shared default without forcing the value to move
  out of `global`.
- **Group values by domain into a nested object as soon as two or more
  keys concern the same concern.** Within any block (`global:` or a
  component), when more than one key relates to the same domain
  (database, OIDC, TLS, signing keys, a sidecar, …), nest them under a
  single object named for that domain instead of leaving a flat run of
  prefixed scalars. Drop the now-redundant prefix from each sub-key —
  the object name carries it. For example, prefer
  ```yaml
  database:
    # -- (string) Connection string. Unset → built from the managed cluster.
    url: ~
    # -- (string) Name of a pre-existing Secret holding key `DATABASE_URL`.
    existingSecret: ~
    # -- Maximum size of the connection pool.
    maxConns: 25
    # -- Minimum number of idle pooled connections.
    minConns: 5
  ```
  over the flat `databaseUrl` / `databaseUrlSecret` / `dbMaxConns` /
  `dbMinConns`. A lone key for a domain stays flat — only group once the
  second related key appears (the rule of two for grouping). The object's
  shape still maps cleanly onto its env vars / flags at the template
  boundary (e.g. `database.maxConns` → `DATABASE_MAX_CONNS`); grouping is a
  `values.yaml` ergonomics rule, it does not change the wire/env contract.
- Expose RBAC `rules` (and an appended `extraRules: []`) in `values.yaml`,
  not hardcoded in the `ClusterRole` template.
- Document **every** key in `values.yaml` with a `helm-docs` `# --`
  annotation immediately above it — no value is allowed to ship
  undocumented, including nested keys and empty defaults (`[]`, `{}`,
  `~`). The comment must describe what the value does, not just restate
  its name.
- For an **unset / undefined** value in `values.yaml`, use `~` (YAML
  `null`) rather than an empty string, a placeholder, or omitting the
  key. For an **empty collection**, use `{}` for an unset dict and `[]`
  for an unset list — never `~` for those, so the consumer knows the
  shape they are overriding. Whenever the default is `~`, `{}`, or `[]`,
  `helm-docs` cannot infer the type from the value, so you **must**
  annotate it explicitly with `# -- (<type>) …` (e.g. `(string)`,
  `(int)`, `(bool)`, `(object)`, `(list)`, `(tpl/string)`). Examples:
  ```yaml
  # -- (string) Optional override for the image tag. Defaults to `.Chart.AppVersion`.
  imageTag: ~
  # -- (object) Extra labels merged into every workload's pod template.
  extraPodLabels: {}
  # -- Extra environment variables to inject into every workload.
  extraEnv: []
  # -- Pod-level security context applied to all workloads.
  podSecurityContext:
    # -- Run all containers as a non-root user.
    runAsNonRoot: true
  ```
- Add the `norwoodj/helm-docs` pre-commit hook (or a local hook invoking
  the installed `helm-docs` binary) to `.pre-commit-config.yaml`. The hook
  must regenerate the chart `README.md` from `values.yaml` and fail when
  the regenerated file differs from the committed one, so an undocumented
  or stale value blocks the commit. Likewise, any generated manifest
  committed to the chart (e.g. a CRD) must have a pre-commit hook that
  regenerates it and fails if it was out of date.
- Add a `helm lint` hook in `.pre-commit-config.yaml` (local hook) that
  runs against every chart directory. If lint needs placeholder values,
  keep them in a `values-lint.yaml` passed with `-f` and excluded from the
  packaged chart via `.helmignore` — never bake them into `values.yaml`.
- Charts must comply with the Kubernetes **Pod Security Standards
  (restricted)** profile. The default `podSecurityContext` /
  `securityContext` shown above is the baseline; do not ship a chart that
  weakens it.
- Always set `resources.requests` for **CPU, memory, and ephemeral
  storage**, and `resources.limits` for **memory and ephemeral storage
  only**. Memory and ephemeral storage are non-compressible and must be
  capped to protect the node; CPU is compressible and a `limits.cpu`
  causes unnecessary throttling, so leave CPU unlimited. Every workload
  must declare all five values — `requests.cpu`, `requests.memory`,
  `requests.ephemeral-storage`, `limits.memory`,
  `limits.ephemeral-storage`. Example default:
  ```yaml
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
      ephemeral-storage: 64Mi
    limits:
      memory: 128Mi
      ephemeral-storage: 256Mi
  ```

**Never:**

- Never ship a chart with a permissive or missing security context.
- Never add a key to `values.yaml` without a `helm-docs` `# --` comment
  above it, and never ship a chart whose `README.md` is out of sync with
  `values.yaml` — the `helm-docs` pre-commit hook must catch both.
- Never write an undefined value as `null`, `""`, or a placeholder string
  — use `~` for a scalar, `{}` for a dict, `[]` for a list. Whenever the
  default is `~`, `{}`, or `[]`, never omit the `# -- (<type>) …` type
  hint, otherwise the generated `README.md` shows no type at all.
- Never leave a flat run of prefixed scalars (`databaseUrl`,
  `databaseUrlSecret`, `dbMaxConns`, …) when two or more keys share a
  domain — nest them under a domain object (`database: { url, … }`) and
  drop the redundant prefix.
- Never duplicate a value across two or more component blocks in
  `values.yaml` — promote it to `global:` instead.
- Never create a `templates/<component>/` directory for a component that
  renders only one object — put it at `templates/<kind>.yaml` at the root.
  Conversely, never leave two-or-more objects of the **same** Kind
  ungrouped at a component's top level — nest them in a
  `templates/<component>/<kind>/` subdirectory. Never mix two components'
  objects under one `<component>/` directory.
- Never hardcode env vars, volumes, or volume mounts that users cannot
  extend via `extraEnv` / `extraVolumes` / `extraVolumeMounts`.
- Never create a `Gateway` or `GatewayClass` from an application chart —
  these are shared cluster infrastructure. Create only the route
  (`MCPRoute` / `HTTPRoute` / …) and attach it to an existing, named
  gateway.
- Never set `resources.limits.cpu`. Memory and ephemeral-storage limits
  only.
- Never omit any of `requests.cpu`, `requests.memory`,
  `requests.ephemeral-storage`, `limits.memory`, or
  `limits.ephemeral-storage` — workloads without requests are best-effort
  QoS and will be evicted first under pressure, and an unbounded
  ephemeral-storage write can fill the node disk.
