---
name: kopf-conventions
description: >-
  kopf mechanics for Python Kubernetes operators.
  TRIGGER when: code imports `kopf` or defines `@kopf.on.*`/`@kopf.timer`
  handlers; wiring `OperatorSettings`; emitting events from a Python operator;
  user asks why events don't show up, or about `kopf.event`,
  `kopf.TemporaryError` or `on.resume`.
  SKIP when: the operator is not kopf, or the question is framework-agnostic
  reconcile design (`kubernetes-operator-conventions`).
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
   posts **iff `settings.posting.enabled` is True** (the default), whatever
   `posting.level`. The shorthands also check the level: `kopf.info` needs
   `level <= INFO`, `kopf.exception` `level <= ERROR`, and `kopf.warn`
   `level <= WARNING` while ignoring `enabled`. Full control over
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

kopf's log-to-event handler posts a record only when **all** of these hold: `posting.enabled`, `record.levelno >= posting.level`,
**`posting.loggers`**, and the record carrying a `k8s_ref` (i.e. it was logged
on the *object* logger, not a module-level `logging.getLogger(...)`).

### Surfacing errors as events — post them explicitly

- **Explicit lifecycle events: the failure event.** Post your own events at
  the reconcile level — good `reason`s, one event per outcome, no framework
  duplication. Wrap the handler:

  ```python
  @kopf.on.create(GROUP, VERSION, PLURAL)
  @kopf.on.resume(GROUP, VERSION, PLURAL)
  @kopf.on.update(GROUP, VERSION, PLURAL)
  async def reconcile(spec, body, name, logger, **_):
      try:
          changed = await _reconcile(spec, body, name, logger)
      except Exception as exc:
          logger.error("reconcile failed", extra={"cause": str(exc)})
          kopf.event(body, type="Warning", reason="ReconcileFailed",
                     message=f"Reconcile failed: {exc}")
          if isinstance(exc, kopf.TemporaryError):
              raise
          raise kopf.TemporaryError(f"reconcile failed: {exc}") from exc
      if changed:
          kopf.event(body, type="Normal", reason="Reconciled",
                     message="Desired state applied.")
  ```

  Make the raised `TemporaryError` message carry the failing operation + cause
  (e.g. `"creating the backing database failed: 500 ..."`) so the single
  rolled-up `ReconcileFailed` event still names what broke; anything else is
  wrapped, never re-raised raw, and the requeue holds either way. `_reconcile`
  returns whether it changed anything: `on.resume` runs it for every CR at each
  operator start, and a steady-state pass posts nothing.

- **Log-posted events: extra detail, never the failure event.** To add one
  event per failing operation from the requeue chokepoint without plumbing
  `body` everywhere, set all three in the startup handler:

  ```python
  settings.posting.enabled = True
  settings.posting.loggers = True
  settings.posting.level   = logging.WARNING   # NOT the INFO default
  ```

  Without raising the level off its `logging.INFO` default, **every** info line
  becomes an event and floods the object. That level also silences
  `kopf.info`, so post Normal events with `kopf.event(type="Normal")`, as the
  wrapper above does. Even then the posted events carry
  `reason="Logging"` (less descriptive than an explicit one), and the framework
  may also post its own error log — expect duplicates.

Log posting never replaces the explicit Warning that
`kubernetes-operator-conventions` requires: it hangs on three settings and on
logging through the object logger, so a settings refactor or a module-level
logger drops the event without a sound. Don't half-set it (`enabled` without
`loggers`) and assume errors post — they won't.

### Cluster-scoped objects & other event gotchas

- **Events are namespaced; cluster-scoped CRs are not.** For a cluster-scoped
  object kopf posts the event into the operator's *own* namespace
  (`get_default_namespace()`, falling back to `default`), with `involvedObject`
  pointing at the CR. `kubectl describe <clusterscoped>` still finds it by uid.
- **RBAC.** The operator's (Cluster)Role needs this rule; missing it is
  silent (see next point):

  ```yaml
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
  ```
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

## Memory footprint — size the Pod above the kopf baseline

kopf carries a real resting memory cost: the framework plus the Kubernetes
client and its watch/peering caches idle well above a naive `128Mi`, so a
chart that ships that as the limit gets the operator `OOMKilled` under normal
watch load — before any work happens.

- Default the Pod's **memory request to `256Mi`** and **limit to `512Mi`**.
  CPU stays uncapped (compressible) — set only a request (e.g. `100m`).
  These come on top of the requests and limits `helm-conventions` requires
  (CPU and ephemeral storage included).
- If the Pod restarts with reason `OOMKilled`, raise the memory limit first;
  don't chase a leak prematurely — it's usually just the kopf baseline.

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
