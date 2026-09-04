---
name: terraform-conventions
description: >-
  Terraform / OpenTofu conventions (file layout with a mandatory
  `data.tf`, naming, typed and documented variables, pinned providers, secrets
  out of the state, `terraform test`, pre-commit hooks, trivy `AVD-xxxx`).
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
| `terraform.tf` | the `terraform {}` block — `required_version`, `required_providers` — and the `provider` blocks |
| `backend.tf` | the `backend` / `cloud` block, when it is not in `terraform.tf` |
| `variables.tf` | every `variable` block |
| `outputs.tf` | every `output` block |
| `locals.tf` | every `locals` block |
| **`data.tf`** | **every `data` block** |
| `<domain>.tf` | the resources for one domain: `network.tf`, `gke.tf`, `dns.tf`, `cloudsql.tf`, … |

- **Every `data` block lives in `data.tf`. No exceptions.** Not next to the
  resource that consumes it, not "just this one because it's only used here".
  Data sources are the stack's inputs from the outside world — the things it
  reads but does not own — and that list is the first thing anyone auditing a
  stack wants: what does this depend on that it did not create? Scattered
  across eight domain files, that question takes a `grep`; in `data.tf` it
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
- The same "all of a kind in one file" rule is what `variables.tf`,
  `outputs.tf` and `locals.tf` already encode — `data.tf` completes the set.
  Resources are the exception, and only because there are far more of them:
  they group by domain.
- A file that outgrows a screen or two is usually two domains wearing a
  trenchcoat. Split it by domain, never by resource type.
- Modules live in `modules/<name>/` and repeat the exact same layout
  internally, `data.tf` included.

## Naming

- `snake_case` for everything: files, variables, outputs, locals, resource and
  data labels.
- **Never repeat the type in the label.** `resource "google_compute_subnetwork"
  "nodes"`, not `"nodes_subnetwork"` — the reference already reads
  `google_compute_subnetwork.nodes`.
- Label a singleton `this`. Label the rest by role (`nodes`, `platform`,
  `controlplane`), never by index or by environment.
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
- Defaults are fine, and good, when a value is genuinely stack-specific and
  stable (a cluster name, a region). Leave a variable without a default when
  omitting it should be an error.
- `terraform.tfvars` carries the per-stack values, commented; secrets never
  go in it.

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
- Never hardcode a value that varies between stacks — variable or local.
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

- Never put a `data` block anywhere but `data.tf`, and never split `data.tf`
  into per-domain data files.
- Never put a `variable`, `output` or `locals` block in a domain file.
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
