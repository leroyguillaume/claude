---
name: helm-conventions
description: >-
  Helm charts: values, security context, KSV, templates, helm-docs, resources.
  TRIGGER when: editing a chart's `templates/`, `values.yaml`,
  `values-*.yaml`, `Chart.yaml`, `.helmignore` or `README.md`; adding a
  Kubernetes object to a chart; user asks about Helm values, RBAC, security
  context, KSV findings or helm-docs.
  SKIP when: no chart file is touched and the user isn't asking about Helm.
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
    runAsUser: 65532
    runAsGroup: 65532
    fsGroup: 65532
    seccompProfile:
      type: RuntimeDefault
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
  ```
  The IDs must be **> 10000** (Trivy `KSV-0020` / `KSV-0021`: a low container
  UID collides with the host's user table). 65532 is the `nonroot` UID used
  by distroless and Chainguard images — keep it in sync with the `USER` baked
  into the image (see `docker-conventions`), otherwise a
  `readOnlyRootFilesystem` pod hits permission errors on its own state
  directory.
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
    existingSecret:
      # -- (string) Name of a pre-existing Secret holding the connection string. Set → takes precedence over the generated one.
      name: ~
      # -- Key in that Secret holding the connection string.
      key: DATABASE_URL
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
- **An `existingSecret` value is always an object `{ name, key }`, never a
  bare string.** Whenever a chart lets the user point at a pre-existing
  Secret instead of generating one, model it as a nested object: `name`
  (default `~` — unset means "generate the Secret from the inline value")
  and `key` (the entry to read, defaulting to the same key the generated
  Secret would use, e.g. `DATABASE_URL` / `UPSTREAM_HEADERS`). A bare
  `existingSecret: ~` string hardcodes the key and cannot consume a Secret
  whose entry is named differently — which is exactly the case
  pre-existing Secrets (sealed-secrets, External Secrets, cloud-synced
  ones) hit. Wire it through two template helpers — a `…SecretName` (the
  existing `name`, else the generated name) and a `…SecretKey` (the
  existing `key`, else the generated default) — and reference both in the
  `secretKeyRef`. Gate the generated-Secret template and any
  `checksum/…` annotation on `not .Values.<path>.existingSecret.name`.
- **Always expose a `caCerts` override for any workload that makes outbound
  TLS connections** (calling an upstream API, an S3/object-store endpoint, an
  OIDC/JWKS server, fetching a document, …). Users behind a corporate MITM
  proxy or with a private CA need to add a trust anchor without rebuilding the
  image. Model it like an `existingSecret`: an inline bundle that generates a
  Secret, *or* an existing resource the user already manages — and crucially
  allow that existing resource to be a **`ConfigMap`** (the natural home for
  non-secret public CA certs) as well as a `Secret`:
  ```yaml
  # -- Extra CA certificates to trust for every outbound TLS connection. Added
  # on top of the built-in public roots — supply only your private/corporate CA.
  caCerts:
    # -- (string) Inline PEM bundle. Stored in a Secret and mounted. Ignored when `existing.name` is set.
    inline: ~
    # -- Mount the PEM bundle from a resource you already manage, instead of `inline`. Takes precedence over `inline` when `name` is set.
    existing:
      # -- (string) Kind of the resource: `ConfigMap` or `Secret`.
      kind: ConfigMap
      # -- (string) Name of the resource. Set → mounts from it instead of generating a Secret from `inline`.
      name: ~
      # -- Key in the resource holding the PEM bundle (also the mounted file name).
      key: ca-certificates.crt
  ```
  Wire it through helpers mirroring the `existingSecret` pattern —
  `caCertsEnabled` (inline or existing set), `caCertsValidate` (fail fast if
  `existing.kind` is neither `ConfigMap` nor `Secret`), `caCertsFromConfigMap`,
  `caCertsGenerateSecret` (inline and no existing), `caCertsSecretName`,
  `caCertsKey`, and a `caCertsPath` for the mount. Gate the generated Secret
  and the `checksum/ca-certs` pod annotation on `caCertsGenerateSecret`; the
  volume picks `configMap:` vs `secret:` from `caCertsFromConfigMap`. **Point
  at the mounted file with the env vars the app's runtime actually honours, not
  an invented name** — match the language/SDK: Python → `SSL_CERT_FILE`,
  `REQUESTS_CA_BUNDLE`, and `AWS_CA_BUNDLE` (boto3); Go → `SSL_CERT_FILE`;
  Node → `NODE_EXTRA_CA_CERTS`; a Rust/other app that reads its own var → that
  var. Honour the established standard name; never prefix it with the app name.
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
  # -- (list) Extra environment variables to inject into every workload.
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
- **Scan the rendered chart with `trivy config` and fix every `KSV-xxxx`
  finding.** The KSV checks are the reference for what a hardened workload
  looks like (`KSV-0020`/`KSV-0021` UID/GID > 10000, `KSV-0003` drop
  capabilities, `KSV-0014` read-only root filesystem, `KSV-0030` seccomp,
  `KSV-0125` trusted registry, …). Treat them as errors and fix at the
  source — **no self-authorised ignores** (`ci-conventions`). The scan is a
  `pre-commit` hook, so it also gates CI through `quality`:
  ```yaml
  - repo: local
    hooks:
      - id: trivy-chart
        name: trivy config (chart)
        entry: trivy config --exit-code 1 --helm-values charts/<chart>/values-lint.yaml charts/<chart>
        language: system
        pass_filenames: false
        files: ^charts/<chart>/
  ```
  Two traps worth knowing:
  - **A chart that fails to render is reported as "Not scanned", and trivy
    still exits 0.** Any `required` value or `fail` in a template silently
    disables the whole scan. That's why a dedicated `values-lint.yaml`
    supplying the required values is part of the chart, and why the
    `helm lint` hook takes the same file: a chart that does not render fails
    there instead of passing here having checked nothing.
  - Because it scans *rendered* output, findings depend on the values you
    feed it. Lint with the defaults a user actually gets, not a
    hardened-on-purpose set that hides the problem.
  Two checks this convention deliberately does **not** follow, because they
  are wrong for a chart rather than wrong in the chart:
  - **`KSV-0011` (`resources.limits.cpu`)** — see the resources rule below;
    CPU limits cause throttling and we intentionally omit them.
  - **`KSV-0110` (`metadata.namespace` is `default`)** — a chart takes its
    namespace from `helm install --namespace`; hardcoding it in templates is
    the actual anti-pattern.
  They are standing, pre-authorised exceptions, excluded from the gate by a
  `.trivyignore` at the repository root, which `trivy` reads from the
  working directory `pre-commit` runs in. Add it without asking, with exactly
  these two IDs:
  ```text
  # No CPU limit: a limit throttles a compressible resource.
  KSV-0011
  # The namespace comes from `helm install --namespace`.
  KSV-0110
  ```
  Only these two. Any other `KSV-xxxx` finding gets fixed, or raised with
  the user.
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
- **Always set `revisionHistoryLimit` on every workload that keeps a
  rollout history** — `Deployment`, `StatefulSet`, `DaemonSet`. Expose it
  as a documented key in the component's `values.yaml` block (default `0`)
  and reference it from the template; never hardcode it and never leave it
  out. Kubernetes defaults to `10`, so an unset field silently piles up ten
  stale ReplicaSets or ControllerRevisions per workload — noise in
  `kubectl get rs`, and etcd objects nobody will ever roll back to. Git is
  the record of what was deployed: a rollback is a revert and a redeploy,
  the same answer `argocd-conventions` gives for the Application.
  ```yaml
  # values.yaml
  <component>:
    # -- Number of old revisions the workload keeps for rollback.
    revisionHistoryLimit: 0
  ```
  ```yaml
  # templates/<component>/deployment.yaml
  spec:
    replicas: {{ .replicaCount }}
    revisionHistoryLimit: {{ .revisionHistoryLimit }}
  ```
  The equivalent knobs on other kinds are **not** this field and are not
  covered by this rule: a `CronJob` uses
  `successfulJobsHistoryLimit` / `failedJobsHistoryLimit`, and a `Job` has
  no history at all.

**Never:**

- Never ship a chart that weakens the restricted security context.
- Never add a `values.yaml` key without a `# --` comment, or a `~`/`{}`/`[]`
  default without its `(<type>)` hint.
- Never write an unset value as `null`, `""` or a placeholder.
- Never leave a flat run of prefixed scalars where a domain object fits.
- Never duplicate a value across component blocks; promote it to `global:`.
- Never put one component's templates under another's directory, or give a
  single-object component a directory of its own.
- Never hardcode env vars, volumes or mounts users cannot extend.
- Never ship an outbound-TLS workload without a `caCerts` override.
- Never create a `Gateway` or `GatewayClass` from an application chart.
- Never ship a workload with a rollout history but no `revisionHistoryLimit`
  from `values.yaml`.
- Never set `resources.limits.cpu`, and never omit any of the five
  requests and limits.
- Never add a `.trivyignore` entry beyond `KSV-0011` and `KSV-0110`.
