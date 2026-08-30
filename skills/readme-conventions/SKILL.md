---
name: readme-conventions
description: README conventions (English only, three mandatory blocks —
  description, getting started, contributing/licence links — operational
  content only, design rationale lives in `ARCHITECTURE.md`).
  TRIGGER when: creating or editing any `README.md`; scaffolding a new
  project; a change alters install/config/run/deploy instructions;
  adding or updating `CONTRIBUTING.md` or `LICENSE`; user asks what belongs
  in the README, how to structure it, or where to document something.
  SKIP when: writing `ARCHITECTURE.md` design rationale with no README impact,
  or editing docs under `docs/` that aren't a README.
---

# README conventions

A `README.md` answers exactly one question: **"I just landed here — what is
this and how do I run it?"** Anything that doesn't serve that question belongs
somewhere else (`ARCHITECTURE.md` for the *why*, `CONTRIBUTING.md` for the
*how do I help*, `docs/` for depth).

**Always in English**, whatever language the project or the conversation is in.

## Mandatory structure

Every README has these blocks, in this order. Nothing else is required; add a
section only when it earns its place.

```markdown
# <project-name>

<One or two sentences: what this is and what it does.>

## Description

<A few short paragraphs — see below.>

## Getting started

### Prerequisites
### Installation
### Configuration
### Usage

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

<SPDX name> — see [LICENSE](LICENSE).
```

### 1. Description

Three to ten lines. A reader must be able to decide, from this block alone,
whether the project is what they're looking for.

- **What it is** — the one-liner, in plain words. `A Kubernetes operator that
  rotates database credentials`, not `A cloud-native solution leveraging…`.
- **What problem it solves** — the itch it scratches, one sentence.
- **What it is not**, when there's an obvious confusion to head off ("it does
  not manage the databases themselves").
- Key features as a short bullet list, only if it genuinely clarifies scope.

Not here: architecture diagrams, design trade-offs, tech-stack justification,
benchmarks, roadmap. Those go in `ARCHITECTURE.md` — link to it from the end
of the description if there is one:

```markdown
See [ARCHITECTURE.md](ARCHITECTURE.md) for the design and the reasoning behind it.
```

Badges (CI status, licence, version) go on a single line under the title, or
not at all. A wall of badges is decoration, not documentation.

### 2. Getting started

**The core of the file.** A newcomer must be able to copy-paste their way from
zero to a running project without leaving this section.

- **Every command in a fenced block, tagged with its language**, one runnable
  command per line, no `$` prompt, no interleaved output.
- **Prerequisites first**, with versions when they matter: `Python ≥ 3.13`,
  `uv`, `Docker ≥ 25`, `kubectl` + a cluster. State only what's actually
  required to follow the steps below.
- **Installation** — clone + install, or the package-manager one-liner.
  Derive the clone URL from `git config --get remote.origin.url`
  (see `project-metadata-conventions`), never invent it.
- **Configuration** — a table of environment variables, with defaults and
  whether they're required:

  ```markdown
  | Variable | Required | Default | Description |
  | --- | --- | --- | --- |
  | `DATABASE_URL` | yes | — | PostgreSQL connection string |
  | `BIND_ADDR` | no | `0.0.0.0:8080` | Address the HTTP server listens on |
  ```

  Never put a real secret value in that table — placeholders only.
- **Usage** — the shortest path to the thing actually working, and a couple of
  the most common invocations after it. If the project is a library, show a
  minimal code example instead.
- **Deployment**, when it applies — how to build the image / apply the chart /
  run the terraform, commands only.

Every command must actually work as written, from a fresh clone, in that
order. Run them if you can; a README that lies is worse than no README.

### 3. Contributing and licence

Two short sections at the bottom, each a link, not a copy:

- **Contributing** — one line pointing at [`CONTRIBUTING.md`](CONTRIBUTING.md).
  Do not restate the workflow in the README; one home per fact.
- **License** — the SPDX identifier or full name, then a link to the `LICENSE`
  file. Never paste the licence text into the README.

## Links

**Every link in the README is either relative *inside* the repo, or an
absolute `https://` URL.** `CONTRIBUTING.md`, `LICENSE`, `ARCHITECTURE.md`,
`docs/deploy.md` — all fine. A path that climbs out of the project root is
not: `../shared/CONTRIBUTING.md` or `../../other-project/README.md` describes
the maintainer's laptop, not the project, and breaks for anyone who clones
elsewhere, in the GitHub/GitLab file viewer, and inside every container build
where the parent directory does not exist. To point at something outside the
repo, use its `https://` URL.

Check the anchors too (`README.md#getting-started`): a heading that moved
takes its anchor with it, and a dead anchor is the usual casualty of a split.

## `CONTRIBUTING.md` and `LICENSE` must exist

A dangling link is worse than a missing section. If the README links them, the
files exist.

- **`CONTRIBUTING.md` missing → create it** as part of the same change, per
  `contributing-conventions`: dev environment setup, pre-commit, what the CI
  runs, how to submit a change. English, like everything else.
- **`LICENSE` missing → ask which licence, then write it.** Picking a licence
  is the user's call and nobody else's: never choose one unilaterally, never
  drop in an MIT file "as a sensible default". Ask, then write the full
  official text with the correct copyright holder and year — holder derived
  from `git config user.name` (see `project-metadata-conventions`). Until the
  user answers, leave the README's licence section out rather than pointing at
  a file that doesn't exist.
- Mirror the licence in the project manifest when there is one
  (`license` in `pyproject.toml` / `Cargo.toml` / `package.json`,
  `Chart.yaml` annotations) so the two never disagree.

## Sub-READMEs

A `README.md` in a subdirectory (a chart, a module, a sub-package) follows the
same shape, scoped to that component: what it is, how to use *it*, and a link
back to the root README. No contributing/licence sections — those live once, at
the root. Generated blocks (`terraform-docs`, `helm-docs`) belong in these files
and stay inside their marker comments; never hand-edit between the markers.

## Keeping it honest

- **Update the README in the same change as the code it describes.** A new
  environment variable, a renamed command, a changed default — same commit.
- **Length is a smell.** Past ~150 lines, the *why* has usually crept in: move
  it to `ARCHITECTURE.md` and link.
- **Never duplicate a section** across `README.md`, `ARCHITECTURE.md` and
  `CONTRIBUTING.md`. One home per fact, links from the others.
- **Running the tests belongs in `CONTRIBUTING.md`**, not here — a user runs
  the project, a contributor runs its test suite. Same for linting and every
  other dev-loop command (see `contributing-conventions`).
- The test for anything ambiguous: **if deleting it would not stop someone from
  installing, running or deploying the project, it does not belong in the
  README.**
