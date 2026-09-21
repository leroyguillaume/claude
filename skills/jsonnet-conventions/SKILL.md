---
name: jsonnet-conventions
description: >-
  Jsonnet conventions — stay simple (no library for a handful of lines, extract only what is big and
  genuinely shared), document every exported function and constant, fail loudly
  at render time, `jsonnetfmt` in pre-commit.
  TRIGGER when: creating or editing any `.jsonnet` / `.libsonnet` file;
  factoring shared jsonnet into a library; user asks about jsonnet structure,
  extVars, libsonnet layout, or whether to extract a helper.
  SKIP when: no jsonnet is being written and the user isn't asking about it.
---

# Jsonnet conventions

**In an existing repository, follow its layout** — where its jsonnet lives,
how it names things — and do not challenge it. The rules below about *what the
jsonnet itself looks like* apply either way.

**Jsonnet is configuration, not a program.** Its reader is someone debugging a
broken deployment at an inconvenient hour, working backwards from the rendered
output to the file that produced it. Every clever construct is one
more hop on that path.

## Stay simple: earn the abstraction

**Do not extract a library for a handful of lines.** A `libsonnet` costs a file
to open, an import to resolve, and a jump away from the manifest being read —
and whatever consumes the output reports errors against the *rendered
output*, never against your abstraction. Four lines repeated three times cost nothing to read and nothing
to change; a helper hiding them costs both, forever.

Extraction has **two axes, and repetition alone is not enough**:

| | small | big |
| --- | --- | --- |
| **repeated twice** | leave it | leave it, note it |
| **repeated three times or more** | leave it | extract |

The rule of three is a necessary condition, not a sufficient one. Three copies
of a four-line `ConfigMap` stay three copies. One eighty-line object that every
app must render *identically* is a library on its first duplication, because
there the risk is not typing it again — it is the copies diverging without
anyone noticing.

Extract when at least one of these is true, and say which in the file header:

- It is **big** — enough that a copy would be reviewed by scrolling past it.
- It carries a **non-obvious invariant** that must hold everywhere (a label
  another controller selects on, a UID, a naming scheme two systems agree on).
- It is a **genuine template** — the shared shape every app instantiates.

And do not:

- **Add a parameter for a caller that does not exist.** No `enabled` flag with
  one call site, no branch taken by nobody. When the second caller shows up it
  will want something you did not guess.
- **Build inheritance chains.** One level of `+` or `+:` over a base object is
  readable; three is a debugging session. If you cannot see the final object in
  your head, neither can the person on call.
- **Reach for jsonnet when nothing varies.** A manifest with no computation is
  a `.yaml` file. Jsonnet earns its place by computing something: reading a
  config value, deriving a name,
  fanning out over a list.
- **Hide a difference inside an abstraction.** Duplication that is obviously
  duplicated beats a helper whose two call sites differ in a way you have to
  read the body to find.

## Document every exported function and constant

This is the deliberate exception to the sparse-comment rule, and it is narrow:
**the contract of a library export is documented; the body is not.**

The reason is specific to the language. Jsonnet has no types and no
signatures — `new(name, app)` tells the reader nothing about what `app` must
contain — and it evaluates lazily, so a field the caller forgot surfaces as an
error somewhere else entirely, often inside a manifest that looks unrelated.
The comment is the only place that contract can live.

For every **function** exported from a `libsonnet`, in two to five lines:

- what it returns (the kind of object, or the shape),
- what each parameter is — format, units, allowed values, which keys an object
  parameter must carry and which are optional,
- what it assumes about its context: an extVar being set, a namespace, a CRD
  existing.

For every **constant**: where the value comes from (a `tofu output`, an
upstream default, a measurement, a hard limit) and **what breaks if it
changes**. A bare number with no provenance is a number nobody dares touch.

Keep it a contract, not an essay:

```jsonnet
// A NetworkPolicy allowing ingress to `port` from the namespaces in
// `fromNamespaces` (a list of names, matched on the standard
// kubernetes.io/metadata.name label). Renders without a namespace: the
// caller decides where it lands.
allowFrom(name, port, fromNamespaces):: { ... }
```

Not this — it restates the signature and buys nothing:

```jsonnet
// Creates a new network policy.
allowFrom(name, port, fromNamespaces):: { ... }
```

**Every `.libsonnet` gets a file header**: what this library is for, in two or
three lines. **Inside function bodies the normal rule applies** — no
narration, comments only where the code is genuinely surprising, and then
saying what breaks without the line.

## Fail loudly at render time

A missing value must stop the render, never produce a plausible manifest. An
empty string interpolated into a ConfigMap deploys, reports healthy, and fails at
runtime with no clue pointing back here.

- Read a required config value directly (`config.registry.host`): jsonnet
  errors on a missing field, which is the behaviour you want.
- Use `std.get(obj, 'key', default)` **only where the key is genuinely
  optional** and the default is correct. It is not a way to make an error go
  away.
- For anything a schema cannot express, `error` with a message naming the
  file and the fix:

  ```jsonnet
  if !std.objectHas(config, 'oidc') then
    error 'config.oidc is missing; SSO cannot be rendered without it'
  ```

## Idioms

- **Imports at the top**, one per line, `local` bindings named after the
  thing, not the path. Resolve them against a library search path (`-J`),
  so they are stable regardless of the importing file's depth.
- **Decode extVars once**, at the top of the file:

  ```jsonnet
  local config = std.parseJson(std.extVar('config'));
  ```

- **Hide library members with `::`**, so importing a library never leaks its
  helpers into a rendered manifest. A field that must render uses a single `:`.
- **Conditional fields** rather than building the object twice:

  ```jsonnet
  [if std.length(items) > 0 then 'items']: items,
  ```

  Mind **absent versus empty** — for several Kubernetes fields, `[]` and a
  missing key mean different things to the API server, and the conditional
  field is how you express the difference.
- **`%` formatting for derived strings** (`'%s-%s' % [prefix, name]`), not
  chained `+`.
- **A `.jsonnet` producing manifests evaluates to a list**, even when there
  is one. A list of one stays a list; the next manifest is then an
  added line rather than a restructure.
- `std.set` to dedupe, `std.objectFields` to iterate a map, `std.flattenArrays`
  over nested comprehensions. Prefer a comprehension to a fold.
- **Never `std.native` or anything that reaches outside the render.** The
  render must be a pure function of the repository and the extVars, or two
  renders of the same commit stop producing the same output.

## Cloud-specific shapes: a function per provider, picked by the caller

When the same resource takes a different shape per cloud or provider (GKE vs
AKS, GCS vs Azure Storage), **never branch on it inside a shared manifest** —
no `if std.objectHas(config, 'gcsBucket') then … else …`, no assert that
exactly one of two provider keys is set. Shared jsonnet stays
provider-agnostic.

Instead:

- Write **one function per provider** in a library, named after the provider
  (`promptLogs.gcp(bucket)`, `promptLogs.azure(account, fileSystem)`), each
  taking exactly the arguments that provider needs — no optional parameters
  covering the other one.
- **Call it from the jsonnet that already knows the provider** — the file
  specific to one environment or cluster. The choice is then made where it is
  obvious, in one line, and the rendered shape can be read off the call site.

The library earns its place here from the invariant the constructors share
(a resource name another manifest refers to, the key spelling a binary reads),
not from line count, so the "no library for a few lines" rule above does not
apply.

## Layout and naming

- In a repo you are laying out, libraries live in
  `lib/<domain>/<thing>.libsonnet`, grouped by the system they describe, not
  by the app that happens to use them first. In an existing repo, they go
  wherever its libraries already go.
- **`new(...)` is the constructor**, for the one obvious object a library
  builds. Named alternatives (`allowFrom`, `permitted`) for the rest.
- A library imported by exactly one file and unlikely to gain a second caller
  is not a library — inline it.

## Formatting

`jsonnetfmt` runs in pre-commit over `\.(jsonnet|libsonnet)$`, as a
`language: system` hook shelling out to the real binary — never a Docker-backed
one (see `pre-commit-conventions`):

```yaml
- id: jsonnetfmt
  name: jsonnetfmt
  entry: jsonnetfmt --in-place
  language: system
  files: \.(jsonnet|libsonnet)$
```

Note it in `CONTRIBUTING.md` as a required binary — pre-commit installs
packages, not the tools a system hook shells out to.

**Never:**

- Never extract a library for a few lines, and never on the second copy of
  something small.
- Never add a parameter, flag or branch for a caller that does not exist yet.
- Never export a function or constant from a library without its contract
  comment — and never narrate the body to compensate.
- Never use `std.get` with a default to paper over a value that is actually
  required.
- Never reach outside the render (`std.native`, environment lookups): the
  same commit must always render the same output.
- Never write jsonnet for a manifest that computes nothing — that is a
  `.yaml` file.
