---
name: kopf-conventions
description: kopf-specific mechanics for Python Kubernetes operators — event
  posting (the posting.enabled vs posting.loggers gotcha), explicit kopf.event
  lifecycle events, cluster-scoped event namespacing, status-based progress
  storage, on.resume rollouts, handler argument injection, and timers.
  TRIGGER when: editing or creating code that imports `kopf` or defines
  `@kopf.on.*` / `@kopf.timer` / `@kopf.on.startup` handlers; wiring
  `OperatorSettings` (posting, persistence, finalizer); emitting Kubernetes
  events from a Python operator; the user asks why events don't show up, about
  `kopf.event` / `kopf.TemporaryError`, progress annotations, or `on.resume`.
  SKIP when: the operator is not Python/kopf (controller-runtime, Operator SDK
  in Go), or the work is framework-agnostic reconcile design — use
  `kubernetes-operator-conventions` for the cross-framework principles.
---

# kopf conventions

kopf-specific implementation details for Python operators. The
framework-agnostic reconcile principles (always-requeue, idempotency,
finalizers, ownerReferences, field manager) live in
`kubernetes-operator-conventions` — this skill is the kopf wiring that those
principles compile down to, plus the sharp edges that bite in practice.

## Events & posting — the model you must get right

kopf has **two completely separate** ways an event reaches the cluster, gated
by **two different settings**. Confusing them is the #1 cause of "I had errors
but no events showed up on the resource".

1. **Explicit calls** — `kopf.event(body, type=..., reason=..., message=...)`
   (and `kopf.info` / `kopf.warn` / `kopf.exception`). These post **iff
   `settings.posting.enabled` is True** (the default). Full control over
   `type` / `reason` / `message`.
2. **Log-record posting** — kopf can mirror log lines made on the **object
   logger** (`logger` injected into a handler) as events. This is gated by
   **`settings.posting.loggers`**, which **defaults to `False`**. When off,
   `logger.error(...)` / `logger.warning(...)` are logged but **never posted**.
   `posting.enabled` does **not** turn this on — only `posting.loggers` does.

### The trap

> **`raise kopf.TemporaryError(...)` does NOT, on its own, post a Kubernetes
> event.** The error event you expect only exists if either (a) you post it
> explicitly with `kopf.event`, or (b) `settings.posting.loggers = True` so the
> framework's error log of the failure becomes an event.

Setting only `settings.posting.enabled = True` (a very common operator setup)
buys you nothing for errors raised via `TemporaryError`, because that path
surfaces through the **logger**, not an explicit `kopf.event`. Any docstring or
skill that says "kopf posts a Warning event for free when you raise
TemporaryError, provided posting.enabled is on" is **wrong** — it needs
`posting.loggers`.

The `K8sPoster` logging handler filter (`kopf/_core/engines/posting.py`)
requires **all** of: `posting.enabled`, `record.levelno >= posting.level`,
**`posting.loggers`**, and the record carrying a `k8s_ref` (i.e. it was logged
on the *object* logger, not a module-level `logging.getLogger(...)`).

### Surfacing errors as events — pick one, deliberately

- **Explicit lifecycle events (preferred for quality).** Keep `posting.loggers`
  off and post your own events at the reconcile level — good `reason`s, one
  event per outcome, no framework duplication. Wrap the handler:

  ```python
  @kopf.on.create(...); @kopf.on.resume(...); @kopf.on.update(...)
  async def reconcile(spec, body, name, logger, **_):
      try:
          await _reconcile(spec, body, name, logger)   # all work; raises via errors.py
      except Exception as exc:
          kopf.event(body, type="Warning", reason="ProvisioningFailed",
                     message=f"Tenant provisioning failed: {exc}")
          raise                                          # re-raise so kopf requeues
      kopf.event(body, type="Normal", reason="Provisioned",
                 message="Tenant fully provisioned.")
  ```

  Make the raised `TemporaryError` message carry the failing operation + cause
  (e.g. `"AI Registry publisher creation failed: 500 ..."`) so the single
  rolled-up `ProvisioningFailed` event still names what broke. Re-raising
  preserves the requeue.

- **Granular log-posted events (set both knobs).** If you want one event per
  failing operation straight from the `errors.py` chokepoint without plumbing
  `body` everywhere, set in the startup handler:

  ```python
  settings.posting.enabled = True
  settings.posting.loggers = True
  settings.posting.level   = logging.WARNING   # NOT the INFO default
  ```

  Without raising the level off its `logging.INFO` default, **every** info line
  becomes an event and floods the object. Even then the posted events carry
  `reason="Logging"` (less descriptive than an explicit one), and the framework
  may also post its own error log — expect duplicates.

Pick explicit events for control; pick `posting.loggers` only when you
genuinely want per-line mirroring. Don't half-set it (`enabled` without
`loggers`) and assume errors post — they won't.

### Cluster-scoped objects & other event gotchas

- **Events are namespaced; cluster-scoped CRs are not.** For a cluster-scoped
  object kopf posts the event into the operator's *own* namespace
  (`get_default_namespace()`, falling back to `default`), with `involvedObject`
  pointing at the CR. `kubectl describe <clusterscoped>` still finds it by uid.
- **RBAC.** The operator's (Cluster)Role needs
  `apiGroups: [""], resources: ["events"], verbs: ["create", "patch"]`. Missing
  this is silent (see next point).
- **POST failures are swallowed.** `events.post_event` catches API errors and
  only emits `logger.warning("Failed to post an event. ... Code: 403 ...")`.
  Events never fail the handling cycle — so when events are mysteriously
  absent, **grep the operator logs for "Failed to post an event"** before
  suspecting your code.
- **Messages are truncated** to 1024 chars by kopf; keep them short.

## RBAC — the operator needs more than its own CRs

The (Cluster)Role must grant, beyond the obvious verbs on your own custom
resources:

- **`apiextensions.k8s.io` / `customresourcedefinitions` — `get, list, watch`
  (cluster scope).** kopf scans CRDs **at startup** to resolve every handled
  resource. Missing this, the operator never starts and crash-loops with
  `customresourcedefinitions.apiextensions.k8s.io is forbidden: User
  "system:serviceaccount:…" cannot list resource "customresourcedefinitions"
  … at the cluster scope`. This is the single most common first-boot RBAC
  failure — add the rule by default whenever you scaffold an operator chart.
- **`""` / `events` — `create, patch`** (post status events; see above).
- **`""` / `namespaces` — `list, watch`** when running cluster-wide
  (`clusterwide=True` / cluster-scoped CRs), so kopf can enumerate namespaces.
- **Peering** (if enabled): `get, list, watch, patch` on
  `kopf.dev/clusterkopfpeerings` (or `zalando.org/clusterkopfpeerings`).
  Disable peering (`settings.peering.standalone = True`) to avoid needing it.

Put these in `values.yaml` as `rbac.rules` (plus `extraRules: []`), never
hardcoded in the template (see `helm-conventions`). When debugging a
crash-looping operator, **read the first lines of the pod log** — an RBAC
`forbidden` at boot points straight at a missing rule above.

## Lifecycle events vs status conditions

Use **explicit `kopf.event`** for *transitions* (provisioned, created,
failed-this-attempt) and **`status.conditions` + `phase`** (written via
`patch.status[...]`) for *ongoing state*. Don't emit an event every reconcile
for steady-state — Events have no dedup (kopf posts with `generateName`, so
each call is a brand-new Event) and a per-interval timer posting the same
failure will spam. Steady "is it healthy right now" belongs in status; "it just
changed" belongs in an event.

## Persistence — keep progress out of annotations

Route kopf's retry bookkeeping into the **status subresource** instead of the
default `kopf.zalando.org/*` metadata annotations, so the object's annotations
stay clean and failures surface through events/logs:

```python
settings.persistence.finalizer = f"{GROUP}/finalizer"
settings.persistence.progress_storage = kopf.StatusProgressStorage()
settings.persistence.diffbase_storage = kopf.StatusDiffBaseStorage()
```

This requires the CRD's `status` schema to allow the extra keys
(`x-kubernetes-preserve-unknown-fields: true` under `status`).

## One reconcile handler for create + resume + update

Register the **same** handler for all three so the desired state is re-applied
uniformly:

```python
@kopf.on.create(GROUP, VERSION, PLURAL)
@kopf.on.resume(GROUP, VERSION, PLURAL)   # fires on operator (re)start
@kopf.on.update(GROUP, VERSION, PLURAL)
async def reconcile(...): ...
```

`on.resume` is what makes a **version bump / Deployment roll re-apply** the new
desired state to every existing CR — template changes shipped in a new operator
version reach CRs created by an older one. This only works if every step is
idempotent (server-side apply, treat `409`/`404` as success).

## Handler argument injection

kopf injects by **parameter name** — declare only what you use and absorb the
rest with `**_`:

- `body` (full `kopf.Body`) — pass this to `kopf.event(...)` and read
  `body["metadata"]["uid"]` for ownerReferences / child pruning.
- `spec`, `name`, `namespace`, `uid`, `status`, `patch` (write status via
  `patch.status[...]`), `logger` (the **object** logger — use it, not a
  module logger, or you lose the `k8s_ref` that event-posting and structured
  object refs depend on), `meta`, `old`/`new`/`diff` (on updates).

## Timers for post-provision state

Child/external health changes *after* the create/update events have fired. Use
`@kopf.timer(GROUP, VERSION, PLURAL, interval=...)` to roll that up into
`status` on a cadence. A timer that can't read its inputs should requeue like
any reconcile error (see `kubernetes-operator-conventions`) — but don't have it
post an event every tick (spam; use status for ongoing state).

## Anti-patterns to fix on sight

- Assuming `TemporaryError` posts an event with only `posting.enabled` set.
- Logging errors on a **module** logger (`logging.getLogger(__name__)`) inside a
  handler and expecting events — no `k8s_ref`, so it can never post.
- Setting `posting.loggers = True` but leaving `posting.level` at INFO (event
  flood).
- Posting an event every reconcile for steady state instead of using
  `status.conditions`.
- Progress stored in `kopf.zalando.org/*` annotations when the CRD could hold it
  in `status`.
