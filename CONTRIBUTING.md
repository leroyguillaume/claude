# Contributing

This repository holds personal Claude Code configuration: the global
instructions in `CLAUDE.md` and the convention skills under `skills/`. A change
here is almost always a Markdown edit. Open an issue or a pull request on
<https://github.com/leroyguillaume/claude>; the short version is
`pre-commit run --all-files` must be green before you push.

See [README.md](README.md#getting-started) for installing and using the skills.

## Development setup

Two tools are needed beyond `git`:

- [pre-commit](https://pre-commit.com) 4.x — runs the gate.
- [skill-validator](https://github.com/agent-ecosystem/skill-validator) —
  validates `skills/*/SKILL.md` structure, links, content and cross-language
  contamination. The hook runs it too, but running it directly gives faster
  feedback and is the only way to check external links (see
  [Running the tests](#running-the-tests)). Install the version the hook's
  `rev` pins in [.pre-commit-config.yaml](.pre-commit-config.yaml), which needs
  a [Go](https://go.dev/doc/install) toolchain.

pre-commit builds two hooks (`actionlint`, `skill-validator`) from source with
the Go on `PATH`, and downloads a toolchain of its own when there is none.

**macOS**

```bash
brew install pre-commit
```

**Linux**

```bash
pipx install pre-commit
```

**Both**

```bash
go install github.com/agent-ecosystem/skill-validator/cmd/skill-validator@<rev>
```

Then, from a fresh clone:

```bash
pre-commit install
```

This installs both the `pre-commit` and the `commit-msg` hook types, as
`default_install_hook_types` in the config asks. In an existing clone, re-run
`pre-commit install` so the `commit-msg` hook type is installed too.

The setup is good when this is green:

```bash
pre-commit run --all-files
```

## Adding or editing a skill

1. Create `skills/<my-skill>/SKILL.md`. The whole `skills/` directory is
   re-included by the allow-list [.gitignore](.gitignore), so a new skill is
   tracked as is; a new file at the repository root is ignored until it gets
   its own `!/<name>` line there.
2. Start it with YAML frontmatter: a `name`, and a `description` that says when
   to load the skill (`TRIGGER when:`) and when to skip it (`SKIP when:`).

   ```markdown
   ---
   name: my-skill
   description: >-
     One line on what this covers.
     TRIGGER when: <conditions that should load the skill>.
     SKIP when: <conditions where it is irrelevant>.
   ---

   # My skill

   The actual conventions go here.
   ```

   The `description` is a folded block scalar (`>-`), or `skill-validator`
   rejects it; [ARCHITECTURE.md](ARCHITECTURE.md#design-decisions) says why.
3. Do not list the skill in [CLAUDE.md](CLAUDE.md): clients list the available
   skills themselves, and a copy there only goes stale.

## Running the tests

There is no test suite to run: the "code" is Markdown, and its correctness is
what the linters assert. `skill-validator` is what plays that role — it is the
only check that can fail on the content of a change rather than its formatting.

Validate every skill:

```bash
skill-validator check --strict skills/
```

Validate a single skill while iterating:

```bash
skill-validator check --strict skills/rust-conventions
```

Check the external links, which needs the network:

```bash
skill-validator validate links skills/
```

`check` reports four groups — `structure`, `links` (relative ones only),
`content`, `contamination` — and `--only` / `--skip` select among them. Two
failures come up often:

- **`parsing frontmatter YAML: mapping values are not allowed in this
  context`** — the `description` is a plain scalar rather than `>-`; see
  [Adding or editing a skill](#adding-or-editing-a-skill).
- **`SKILL.md body is N tokens (spec recommends < 5000)`** — the skill has
  grown past what is loaded into context comfortably. Split it into a second
  skill with its own `TRIGGER`, rather than moving prose into `references/`:
  a sibling skill is loaded automatically when its triggers match, whereas a
  `references/` file is only read if something opens it.

## Pre-commit hooks

`pre-commit install` is part of the setup above; the hooks must pass before you
push.

```bash
pre-commit run --all-files
```

```bash
pre-commit run <hook-id> --all-files
```

From [.pre-commit-config.yaml](.pre-commit-config.yaml):

| Hook | What it checks | How to fix |
| --- | --- | --- |
| `trailing-whitespace`, `end-of-file-fixer` | Whitespace hygiene | Fixed in place; re-stage and re-run |
| `check-yaml` | YAML parses | Fix the syntax error it points at |
| `check-added-large-files` | No large blob committed | Don't commit the blob |
| `check-merge-conflict` | No conflict marker left behind | Finish the merge |
| `detect-private-key` | No private key committed | Remove it, then rotate the key |
| `yamllint` | YAML style, per [.yamllint.yaml](.yamllint.yaml) | Fix the finding; block style only, no `---` opening a file |
| `actionlint` | Workflow files are valid | Fix the expression or key it names |
| `skill-validator` | Skill structure, relative links, content, contamination | See [Running the tests](#running-the-tests) |
| `no-co-authors` (`commit-msg` stage) | No `Co-Authored-By:` trailer or `Generated with` line in the commit message. Runs on `git commit` only: `pre-commit run --all-files`, and so CI, skips it | Rewrite the message; a commit has one author |

`--no-verify` and `SKIP=` are not the fix. A red hook is a real finding: fix
the content, or change the hook configuration in the same pull request and say
why. The same hooks run in CI, so skipping locally only moves the failure
somewhere slower.

## Continuous integration

| Workflow | Triggers on | What it does | Reproduce locally |
| --- | --- | --- | --- |
| [`quality.yaml`](.github/workflows/quality.yaml) | push to `main`, every PR, weekly | `pre-commit` job: `pre-commit run --all-files`. `skills` job: re-runs `skill-validator check` with `--emit-annotations` so findings land on the diff, then checks the external links | `pre-commit run --all-files` and `skill-validator validate links skills/` |

The `pre-commit` and `skills` checks are required to merge into `main`. The
weekly run is for the external links: a documentation URL dies without any file
here changing.

The external-link check is not a pre-commit hook because it needs the network —
a gate that fails on a train is a gate people learn to bypass.

The workflow needs no secret and only reads the repository, so it runs the same
on a fork's pull request.

[`dependabot.yaml`](.github/dependabot.yaml) opens weekly pull requests for the
action SHA pins, the pre-commit hook revisions and the `pre-commit` version CI
installs ([.github/requirements.txt](.github/requirements.txt)). Minor and
patch updates are grouped into one pull request per ecosystem; each major
update gets its own. They are never automerged.

## Submitting a change

- Commit subjects are imperative, lowercase, with an optional `area:` prefix —
  read `git log --oneline` and follow what is there.
- Pull requests are squash-merged, so the pull request title becomes the
  commit subject on `main`: write it in the same style.
- A pull request needs green CI and no `TODO` left behind in a committed file:
  work that remains goes in an issue.
