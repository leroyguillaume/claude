---
name: kubernetes-operator-conventions
description: Kubernetes operator / controller conventions (error handling,
  always-requeue, events, idempotency, finalizers, ownerReferences). Applies to
  kopf, controller-runtime, Operator SDK, or any custom controller reconcile
  loop.
  TRIGGER when: editing or creating reconcile handlers / controllers (e.g. files
  importing `kopf`, `controller-runtime`, `operator-sdk`, or defining
  `@kopf.on.*` / `Reconcile()` functions); handling errors, retries, events, or
  finalizers in a controller; user asks about requeue, reconciliation, CRDs,
  operator error handling, or status conditions in this repo.
  SKIP when: the code is not a controller/operator reconcile path (plain CLI,
  library, web handler) and the user isn't asking about operator behavior.
---

# Kubernetes operator conventions

These rules govern any reconcile path: the handler itself and everything it
calls (clients, token providers, DB access). The mechanics below are written
for **kopf** (this repo's framework); the same principles map onto
controller-runtime (`return ctrl.Result{Requeue: true}, err`) and Operator SDK.

## Error handling — always requeue, never abandon

This is the non-negotiable core rule.

- **A resource is never dropped into a permanently-failed state.** Every
  failure must **requeue** the object so it recovers on its own once the cause
  is fixed (an admin grants RBAC, a CRD gets installed, a dependency comes
  back, the user corrects the spec).
- In kopf this means: **raise `kopf.TemporaryError`** (which logs, posts an
  event, and re-schedules) and **never `kopf.PermanentError`** — a permanent
  error stops the retries, which violates this rule. A bare `raise` of an
  arbitrary exception also requeues, but prefer `TemporaryError` so you control
  the message and delay.
- **Every failure must do three things, uniformly:**
  1. **Log at error level** with the underlying cause as a **structured field**
     — the API `reason` / response `message`, *not* just an HTTP status code,
     and never the raw stack trace as the only signal.
  2. **Emit a Kubernetes Warning event** on the object so it shows up in
     `kubectl describe`. **Do not assume the framework does this for free on a
     raised error.** In kopf specifically, `settings.posting.enabled = True`
     only enables *explicit* `kopf.event(...)` calls — a raised
     `TemporaryError` posts **no** event unless `settings.posting.loggers` is
     also on (it defaults to `False`). Post the event explicitly (e.g. a
     `ProvisioningFailed` Warning from a reconcile wrapper). See the
     `kopf-conventions` skill for the full posting model and the gotcha.
  3. **Requeue** with a sensible delay.
- **Tune the requeue delay by error class**, but always requeue:
  - **Transient** (`5xx`, `429`, network/timeout): retry **quickly** (e.g. 30s).
  - **Client / input** errors (`4xx` such as `422` invalid manifest, `403`
    RBAC; or a failed spec validation): retry **slowly** (e.g. 300s) to avoid a
    hot loop, since they need an external change — but still retry.
- **Centralise this in one module** (e.g. `errors.py`) exposing a `requeue()`
  chokepoint plus `raise_for_*` helpers that extract the cause, log it, and
  requeue. Route every reconcile-path failure through it instead of scattering
  bare `raise_for_status()` / re-raises. Extract the shared helper as soon as a
  second call site appears in a third module (rule of three across the
  operator's I/O surfaces).
- **Validate the spec first** and requeue on invalid input the same way — a
  malformed spec is a slow-retry client error, not a silent no-op and not a
  crash.

Anti-patterns to fix on sight: `raise kopf.PermanentError`; re-raising a raw
`ApiException` / `httpx.HTTPStatusError` out of a handler; logging only
`status` without the reason; swallowing an error and `return`ing so the
resource silently stops reconciling.

## Idempotency

- Reconcile handlers run repeatedly; every side effect must be safe to repeat.
- Treat **already-exists** (`409`) on create and **not-found** (`404`) on
  delete as **success**, not failure — log and continue.
- Prefer create-or-skip / select-then-insert over blind inserts so a retry
  after a partial run never duplicates or errors.

## Ownership, finalizers, garbage collection

- Set an **ownerReference** on every in-cluster child object so Kubernetes
  garbage-collects it when the parent is deleted — don't delete children by
  hand in the delete handler.
- Use a **finalizer** only for teardown Kubernetes can't do itself: external,
  non-Kubernetes resources (SaaS workspaces, DB rows, cloud objects). Make that
  teardown idempotent too (a `404`/already-gone is success).

## CRD manifests — one file per kind, kebab-case filename

When generating CRD YAML (e.g. a `crd` CLI subcommand driven by the Pydantic /
typed spec models), emit **one file per kind into an output directory**, not a
single `--kind` selector or one concatenated file. The generator owns the
filename↔manifest mapping in a single place (e.g. an `all_crds()` registry next
to the builders) so the CLI stays a thin caller and the pre-commit hook is one
entry, not one-per-kind.

Name each file after the **kind in kebab-case**, acronym-aware — never glue the
words together:

- `Tenant` → `tenant.yaml`
- `TenantMCPServer` → `tenant-mcp-server.yaml` (not `tenantmcpserver.yaml`)

Kebab conversion needs two passes: split lower/digit→upper boundaries
(`(?<=[a-z0-9])(?=[A-Z])`), then acronym→word boundaries
(`(?<=[A-Z])(?=[A-Z][a-z])`, the `P`→`Server` split in `MCPServer`), then
lowercase. A naive `.lower()` of the PascalCase kind glues acronyms and is wrong.

Default the command with no output dir to a **multi-document YAML stream on
stdout** (all kinds, `---`-separated). A single pre-commit hook regenerates the
whole `crds/` directory and the `files:` regex covers the spec modules plus
`crds/.*\.yaml`, so the committed CRDs can never drift from the models.

## Optional spec fields — nullable, never `type: "null"`

A Kubernetes **structural schema** rejects both `type: "null"` and an `anyOf`
node that lacks its own `type`. Pydantic emits an optional `T | None` field as
`anyOf: [{type: T}, {type: "null"}]`, which the apiserver refuses on `kubectl
apply` of the CRD. When converting a spec model's JSON Schema to the CRD's
OpenAPI v3 subset, **collapse `<type> | null` unions into the single branch with
`nullable: true`** (carrying over sibling keywords like `description`). The same
converter must strip `additionalProperties: false` wherever it sits next to
`properties` (Pydantic's `extra="forbid"` leaks it, and structural schemas
forbid the pair). Add a test that walks the generated CRD asserting no node has
`type: "null"` nor `additionalProperties: false` beside `properties`.

## Field manager — always identify yourself on writes

Every write to the API (server-side apply, JSON/merge/strategic-merge patch,
create, update) must set an **explicit, stable `field_manager`** equal to the
operator's name (e.g. `tenant-operator`). Never let the client default it:
the apiserver will then attribute the fields to a generic or empty manager,
which is invisible to downstream tooling.

This is non-negotiable because anything that reads `.metadata.managedFields`
relies on the manager name being recognisable:

- **GitOps drift suppression.** ArgoCD's `managedFieldsManagers` (and Flux's
  equivalent) tells the GitOps engine *"this manager owns these fields, don't
  flag them as drift"*. The lookup is by **exact manager name**. If the
  operator's writes don't carry a recognisable manager, the GitOps engine
  cannot defer ownership and the resource stays permanently `OutOfSync`.
- **SSA conflict resolution.** Without a stable manager, two controllers
  fighting over the same field can't be diagnosed (`kubectl get ... -o yaml`
  shows nameless entries) and `force_conflicts` decisions become guesswork.
- **Auditability.** `kubectl get ... --show-managed-fields` becomes the
  canonical answer to *"who last wrote this field?"*. A blank or generic
  manager defeats the audit.

Apply this uniformly: the SSA call, **every** patch helper (`json-patch+json`,
`merge-patch+json`, `strategic-merge-patch+json`), and any direct
`create`/`update`. Centralise the constant (`FIELD_MANAGER = "<operator>"`)
in one module so every I/O call site uses the same string. A patch helper
that silently omits `field_manager` is a bug to fix on sight — even if the
write succeeds, it breaks the contract with GitOps and audit tooling
downstream.

The manager appears in `managedFields` only **after** a successful write to
the resource — creation by another controller is not enough. When debugging
*"my manager doesn't show up"*, force at least one reconcile that actually
writes, then re-check.

## Observability

- Verbosity is controlled **only by the log level** (e.g. `LOG_LEVEL`), never a
  bespoke flag. Emit debug logs around every external call (inputs + outcome)
  and at each decision branch, so a failure is diagnosable from logs alone.
- Log with **structured key-values**, never string interpolation, and **never
  log secrets** (bearer tokens, client secrets, DB URLs).
- Surface user-facing state through **events** and **status conditions**, not
  just logs — the spec author sees `kubectl describe`, not the operator's pod
  logs.

## Documentation

- Document failure/retry semantics in the project `README.md` (a
  *Troubleshooting* section): where to look (events + logs), and the
  requeue-always behaviour with the per-class delays.
