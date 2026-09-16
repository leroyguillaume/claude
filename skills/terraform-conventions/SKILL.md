---
name: terraform-conventions
description: >-
  Terraform / OpenTofu conventions (file layout with a mandatory
  `data.tf` and one file per component, naming, typed and documented
  variables, pinned providers, secrets out of the state, `terraform test`,
  pre-commit hooks, trivy `AVD-xxxx`).
  TRIGGER when: creating or editing any `.tf`, `.tfvars`, `.tftest.hcl`, or
  `.terraform.lock.hcl` file; adding a resource, data source, variable, output,
  local, module or provider; setting up pre-commit or CI for a stack that
  contains Terraform; user asks about Terraform/OpenTofu layout, state,
  providers, modules, plan/apply, tflint, terraform-docs or tfsec/trivy
  findings in this repo.
  SKIP when: no HCL is being written or edited and the user isn't asking about
  Terraform/OpenTofu tooling.
---

# Terraform / OpenTofu conventions

Applies to root stacks and to modules. "Terraform" below means whichever of
`terraform` / `tofu` the repo actually runs — pick one and pin every tool to
it (see the pre-commit section), because a hook that shells out to whatever it
finds behaves one way on a laptop and another way in CI.

## File layout

**One concern per file, named after the concern.** A root stack is a flat
directory of `.tf` files; the filename is the only navigation aid a reader
gets, so it has to mean something. Reserved names, always at the root:

| File | Holds |
| --- | --- |
| `terraform.tf` | the `terraform {}` block — `required_version`, `required_providers` — and every `provider` block |
| `backend.tf` | the `backend` / `cloud` block, always here and never in `terraform.tf` — in its own `terraform {}` block |
| `variables.tf` | every `variable` block |
| `outputs.tf` | every `output` block |
| `locals.tf` | every `locals` block |
| **`data.tf`** | **every `data` block** |
| `<component>.tf` | every resource that exists for one component, whatever its type: `toto.tf`, `billing.tf`; for infrastructure no app owns, the technical building block: `network.tf`, `gke.tf` |
| `terraform.tfvars` | the value of every variable the stack declares |
| `main.tf` | only in a stack whose sole content is one `module` call — never alongside component files |

- **Every `data` block lives in `data.tf`. No exceptions.** Not next to the
  resource that consumes it, not "just this one because it's only used here".
  Data sources are the stack's inputs from the outside world — the things it
  reads but does not own — and that list is the first thing anyone auditing a
  stack wants: what does this depend on that it did not create? Scattered
  across eight component files, that question takes a `grep`; in `data.tf` it
  takes a `cat`. It also makes the blast radius of an external change
  (a renamed zone, a subnet moved to another project) legible in one place,
  and it stops the same lookup being declared twice under two names in two
  files because neither author saw the other's.
  ```hcl
  # data.tf
  # The VPC is shared platform infrastructure -- adopted, never created here.
  data "google_compute_network" "cluster" {
    name    = var.network_name
    project = var.host_project
  }

  data "google_dns_managed_zone" "platform" {
    name    = var.dns_zone
    project = var.host_project
  }
  ```
  Group `data.tf` with a blank line and a comment per logical cluster of
  lookups when it grows; do not split it into `data-network.tf` /
  `data-dns.tf`. One file, one answer.
- **One `locals` block per file, and never a second one appended below the
  first.** HCL merges them, so two blocks parse and plan exactly like one —
  which is the problem: nothing fails, and the file now has two places a local
  could live. A reader looking for `cluster_name` has to scan past the closing
  brace of a block that looked complete, and the next person to add a value
  picks one of the two by coin flip. The split also carries no meaning, because
  HCL gives it none: the blocks are not scopes, not ordering, not visibility.
  Merge them and group with a blank line and a comment instead.

  This is almost always an editing artefact rather than a decision — appending
  to the file with `cat >>` or an editor's "add to end" is one keystroke and
  opening the existing block is several. **Add the value inside the block that
  is already there.** The same applies to a second `terraform {}` block, a
  second `variables`-style grouping, or any other container the layout above
  says there is one of.

- The same "all of a kind in one file" rule is what `variables.tf`,
  `outputs.tf` and `locals.tf` already encode — `data.tf` completes the set.
  Resources are the exception: they group by component.
- **Every resource created for a component lives in `<component>.tf`, named
  after the component — never in a file named after a resource type.** The
  app `toto` needs a secret, a database instance, a database, a service
  account and the IAM bindings that tie them together: all of it goes in
  `toto.tf`. Not `secrets.tf` + `cloudsql.tf` + `iam.tf`, where adding, reviewing or
  deleting one app means touching three files and removing it cleanly means
  hoping you found every piece.
  ```hcl
  # toto.tf
  resource "google_service_account" "toto" {
    account_id   = "toto"
    display_name = "toto"
  }

  resource "google_secret_manager_secret" "toto_api_key" {
    secret_id = "toto-api-key"
    replication {
      auto {}
    }
  }

  resource "google_secret_manager_secret_iam_member" "toto_api_key" {
    secret_id = google_secret_manager_secret.toto_api_key.id
    role      = "roles/secretmanager.secretAccessor"
    member    = google_service_account.toto.member
  }

  resource "google_sql_database_instance" "toto" {
    name             = "toto"
    database_version = var.toto_database_version
    region           = var.region
    settings {
      tier = var.toto_database_tier
    }
  }

  resource "google_sql_database" "toto" {
    name     = "toto"
    instance = google_sql_database_instance.toto.name
  }
  ```
  - **The file is named after the component a resource is created for,
    never after what the resource is.** The database instance created for
    `toto` lives in `toto.tf`, not in `postgres.tf` or `cloudsql.tf` — a
    technology is not a component. When another component uses something
    `toto` created (a database on its instance, an IAM binding on its
    bucket), that addition lives in the consumer's file.
  - **Only infrastructure created for no app in particular is named after
    its technical building block**: the VPC, its subnets and its routers in
    `network.tf`, the cluster in `gke.tf`. The moment a resource exists for a
    component, the component wins.
  - When the same component shape repeats a third time, extract a module in
    `modules/<name>/`; each call still gets its own `<component>.tf` holding
    the `module` block and whatever is specific to that component.
- A file that outgrows a screen or two is usually two components wearing a
  trenchcoat. Split it by component, never by resource type.
- Modules live in `modules/<name>/` and repeat the exact same layout
  internally, `data.tf` included.
- **A stack that only calls a module puts that call in `main.tf`.** There is
  no component to name the file after — the module is the whole stack — so
  `main.tf` is the honest name. The reserved files (`terraform.tf`,
  `variables.tf`, `outputs.tf`, `terraform.tfvars`, …) still apply. The
  moment the stack declares a resource of its own, or a second module call,
  `main.tf` is gone: every block moves to its `<component>.tf`.

## Naming

- `snake_case` for everything: files, variables, outputs, locals, resource and
  data labels.
- **Never repeat the type in the label.** `resource "google_sql_database"
  "toto"`, not `"toto_database"` — the reference already reads
  `google_sql_database.toto`.
- **A resource is labelled after the component it belongs to.** Whether the
  label stops there depends on whether the type already says what the
  resource is:
  - **A self-explanatory type, one of it in the component: the label is
    exactly the component name.** A database, a Mongo cluster, a service
    account, a bucket — `google_sql_database.toto` and
    `google_service_account.toto` say everything.
  - **An ambiguous type: always `<component>_<role>`, even when there is only
    one.** `google_secret_manager_secret.toto` says nothing about what it
    holds; `google_secret_manager_secret.toto_api_key` does. Same for config
    maps, random values, generic IAM bindings — anything whose type names a
    container rather than its content. A binding on a named resource takes
    that resource's label (`google_secret_manager_secret_iam_member.toto_api_key`).
  - **Several self-explanatory resources of one type: all of them
    `<component>_<role>`**, none left bare — `toto_primary` and
    `toto_replica`, never `toto` plus `toto_replica`.
- **A `module` block follows the same rule, with the module's name in place
  of the component's.** One unambiguous call of `modules/postgres` is
  `module "postgres"`. When the name alone does not say which call it is —
  several calls of the same module, or a generic module such as `secret` —
  every call is `<module>_<role>`: `module "postgres_toto"` and
  `module "postgres_billing"`, never `postgres` plus `postgres_billing`.
- `this` only inside a module, where the module is the component. Never label
  by index or by environment.
- Name the *thing*, not its shape: `data.google_project.this`, not
  `data.google_project.project_data`.

## Variables

- **Every variable declares a `type` and a `description`.** No exceptions, no
  bare `variable "foo" {}`. The description is a sentence that says what the
  value does and what happens when it changes — including "this forces
  replacement", which is exactly the fact a reviewer needs and the type cannot
  carry.
- Use precise types: `map(object({...}))` with `optional(x, default)` beats
  `map(any)`. `any` is a promise to debug it at apply time.
- `validation` blocks on anything with a real constraint (a name length, an
  enum, a reserved key, a CIDR). Fail at plan, not at the API's 400.
- `sensitive = true` on anything credential-shaped — and prefer not taking it
  as a variable at all (see Secrets).
- **Prefer a variable to a literal, as far as it goes.** A project ID, a
  region, a machine type, a version, a CIDR, a replica count, a domain — any
  value an operator could plausibly want to read or change without reading
  the resource code is a variable. Literals are for what is the code's own
  identity (a component's name, a role string the API fixes) and nothing
  else. Constructed values stay `locals`, built from variables.
- **A root stack sets every variable's value in `terraform.tfvars`**, one
  file at the stack root, commented where the value is not self-evident. It
  is the stack's configuration at a glance; a value hidden in a `default`
  makes the reader open `variables.tf` to learn what is actually deployed.
  Defaults belong in modules, where they describe the common case for every
  caller. Secrets never go in `terraform.tfvars` (see Secrets).

## Outputs

- **Every output has a `description`.** It is API surface for whatever consumes
  the state — another stack, a GitOps repo, a human.
- Mark credential-shaped outputs `sensitive = true`, and prefer emitting the
  *reference* (a Secret Manager secret name, a resource ID) over the value.
- Output what another stack must agree with, not everything you happen to have.

## Providers and versions

- **Pin provider versions exactly** (`version = "7.16.0"`), and use the fully
  qualified source (`registry.terraform.io/hashicorp/google`). The short form
  resolves to different registries under Terraform and OpenTofu and the two
  fight over `.terraform/providers` and the lock file every time you switch.
- `required_version` gets a floor (`>= 1.11`), justified in a comment when the
  floor is not the obvious one — the feature that moved it.
- **Commit `.terraform.lock.hcl`**, and regenerate it with
  `-platform=` for every platform CI and laptops actually run on.
- Provider configuration stays in the root module. **Never declare a
  `provider` block inside a module** — pass providers in explicitly when a
  module needs an aliased one.

## Resources

- **`for_each` over `count`.** `count` keys state by index, so removing the
  middle element of a list re-creates everything after it. `for_each` keys by
  a stable string. Use `count` only for a genuine on/off toggle
  (`count = var.enabled ? 1 : 0`).
- Never hardcode a value an operator could want to change — variable, with its
  value in `terraform.tfvars` (see Variables).
- Use `locals` for anything constructed more than once (a resource-name format
  string, a principal, a label set), and comment the construction.
- **Use `moved` blocks** to rename or restructure, never `state mv` by hand and
  never a destroy/recreate you did not intend. `import` blocks over
  `terraform import`, so adoption is reviewable in the diff.
- `lifecycle { prevent_destroy = true }` on anything holding data — databases,
  buckets, KMS keys.
- **No `provisioner`, no `local-exec`, no `remote-exec`.** They run on
  someone's laptop, are invisible to the plan, and are not idempotent. If a
  step cannot be expressed as a resource, it belongs in a script the pipeline
  calls, documented in `README.md`.

## Secrets and state

- **Treat the state file as a published document.** Anything a resource
  attribute holds is in it, in cleartext.
- Prefer write-only arguments (`*_wo` with `*_wo_version`) and `ephemeral`
  blocks for generated credentials — the value exists only inside the apply and
  never lands in state. Where the provider offers no write-only form, store a
  reference (a Secret Manager secret name) and let the consumer resolve it at
  runtime.
- Remote state only, versioned and encrypted, with locking.
- Never `output` a secret's value, never write one into `terraform.tfvars`,
  never paste one into a plan output pasted into a PR.

## Tests

- Tests live in `tests/*.tftest.hcl` and run in CI with `terraform test`.
- At minimum: a `plan`-mode test per stack asserting the invariants that
  actually matter (a name format, a count, a flag that must stay off).
- `terraform test` is not a file-scoped lint — run it in CI, not in
  pre-commit.

## Docs

- `README.md` carries the operational content plus the `terraform-docs`
  injected block between `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->`,
  generated from a committed `terraform-docs.yml`.
- The *why* — why this provider, why this floor, why the VPC is adopted rather
  than created, bootstrap and recovery procedures — goes in `ARCHITECTURE.md`.

## pre-commit

Baseline hooks plus, pinned to one binary so laptop and CI agree:

```yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.96.2
  hooks:
    - id: terraform_fmt
      args:
        - --hook-config=--tf-path=tofu
    - id: terraform_validate
      args:
        - --hook-config=--tf-path=tofu
    - id: terraform_tflint
      args:
        - --hook-config=--tf-path=tofu
    - id: terraform_docs
      args:
        - --hook-config=--tf-path=tofu
        - --args=--config=terraform-docs.yml
```

`terraform_docs` must fail when the regenerated `README.md` differs from the
committed one, so an undocumented variable blocks the commit.

## Scanning

**Scan with `trivy config` and fix every `AVD-xxxx` finding at the source.**
Same rule as Helm and Docker: **never** add a `.trivyignore` or an inline
`#trivy:ignore` on your own initiative. If a finding is genuinely wrong for
this stack, say so and get it agreed, then document the exception where the
next reader will find it.

```bash
trivy config --exit-code 1 .
```

## Applying

- **Never run `apply` or `destroy` unless the user explicitly asks.** `plan` is
  always fine and is the default answer to "does this work?". `-auto-approve`
  needs an explicit green light every time; it does not carry forward.
- Read the plan before proposing it: a replacement you did not expect is the
  bug, and the plan is where it is cheapest to find.

**Never:**

- Never put the `backend` / `cloud` block anywhere but `backend.tf`, or a
  `provider` block anywhere but `terraform.tf`.
- Never name a file after a technology (`postgres.tf`, `cloudsql.tf`) when
  its resources exist for a component.
- Never put a `data` block anywhere but `data.tf`, and never split `data.tf`
  into per-component data files.
- Never spread one component's resources across files by resource type
  (`iam.tf`, `secrets.tf`, `databases.tf`) — they all go in `<component>.tf`.
- Never label a component's resource anything but `<component>` (one
  self-explanatory resource of its type) or `<component>_<role>` (an
  ambiguous type such as a secret, or several of a type).
- Never label a `module` block anything but `<module>` (one unambiguous call)
  or `<module>_<role>` (a generic module, or several calls of one).
- Never use `main.tf` in a stack that holds anything besides a single module
  call.
- Never put a `variable`, `output` or `locals` block in a component file.
- Never leave a root stack's variable value in a `default` rather than
  `terraform.tfvars`, and never write a literal where a variable fits.
- Never ship a variable or output without a `description`, or a variable
  without a `type`.
- Never use `any` where a concrete type can be written.
- Never leave a provider version unpinned or use the short registry form.
- Never declare a `provider` block inside a module.
- Never use `count` to iterate over a collection — `for_each`.
- Never use a `provisioner`.
- Never let a secret reach the state file, an output, or `terraform.tfvars`.
- Never hand-edit state or run `state mv` where a `moved` block would do.
- Never silence a `tflint` or `trivy` finding on your own initiative.
- Never run `apply`, `destroy`, or anything `-auto-approve` without an
  explicit ask.
