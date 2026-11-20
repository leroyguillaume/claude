# Contributing

This repository holds Agent Skills, one per directory: a change here is almost
always a Markdown edit. Open an issue or a pull request on
<https://github.com/leroyguillaume/skills>; the short version is `task lint`
must be green before you push.

See [README.md](README.md#getting-started) for installing and using the skills.

## Development setup

[mise](https://mise.jdx.dev/installing-mise.html) is the one tool to install
beyond `git`, activated in your shell as its install page describes:

```bash
brew install mise
```

```bash
curl https://mise.run | sh
```

It installs everything else at the versions [mise.toml](mise.toml) pins, with
their checksums in [mise.lock](mise.lock):

- [pre-commit](https://pre-commit.com) runs the gate, and the Python it
  builds its hook environments with.
- [skill-validator](https://github.com/agent-ecosystem/skill-validator)
  validates every `SKILL.md`'s structure, links, content and cross-language
  contamination. The hook runs it too, but running it directly gives faster
  feedback and is the only way to check external links (see
  [Running the tests](#running-the-tests)).
- [pollen](https://github.com/groupbees/pollen): `pollen validate` checks
  that it can deploy every skill, as the CI does (see
  [Continuous integration](#continuous-integration)).
- [Task](https://taskfile.dev) runs the commands below, defined in
  [Taskfile.yml](Taskfile.yml); `task --list` shows them.

pre-commit builds the `actionlint` hook from source with the Go on `PATH`, and
downloads a toolchain of its own when there is none.

From a fresh clone:

```bash
mise trust
```

```bash
mise install
```

```bash
task setup
```

`task setup` installs both the `pre-commit` and the `commit-msg` hook types, as
`default_install_hook_types` in the config asks.

The setup is good when this is green:

```bash
task lint
```

## Adding or editing a skill

1. Create `<my-skill>/SKILL.md` at the repository root.
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

   The `description` is a folded block scalar (`>-`): a `:` inside a
   multi-line plain scalar is not strict YAML, so `skill-validator` rejects it
   even where Claude Code's own reader accepts it.

   The `description` is the only part of a skill that is always in context,
   and the only thing a client has to decide whether to load it. Name concrete
   file paths and topics in `TRIGGER`: a skill whose triggers are vague never
   loads, and nothing can force it to for a given file. Keep it to routing,
   too — Claude Code caps the combined skill listing at about 1% of the
   context window and drops the least-used skills' descriptions first.
3. Keep the body under 5000 tokens, which `skill-validator` enforces: past
   that a skill crowds out the conversation it is meant to inform. A skill
   that outgrows it is split into a sibling skill with its own `TRIGGER`, the
   way `rust-http-conventions` carries the HTTP stack apart from
   `rust-conventions` — not into `references/`, since a sibling skill loads
   automatically when its triggers match, whereas a `references/` file is only
   read if something opens it.
4. Give each rule one home. A rule that applies to every change whatever the
   technology — a meta-rule or a guardrail — belongs in the client's global
   instructions ([claude-config](https://github.com/leroyguillaume/claude-config)),
   and a skill never restates it in detail. A skill may recall such a rule in
   one line where it bears on it: the skills also deploy to clients that never
   read those instructions, so they cannot drop the reminder.

## Running the tests

The "code" is Markdown, and its correctness is what the linters assert.
`skill-validator` is what plays that role — it is the only check that can fail
on the content of a change rather than its formatting. It asserts that a skill
is well-formed, not that a client applies it: that feedback only exists in the
projects using the skills, through their own linters and CI.

Validate every skill:

```bash
skill-validator check --strict --max-depth 1 .
```

`--max-depth 1` keeps it to the repository's skills: in a clone at
`~/.claude/skills`, Claude Code's `synced/` directory holds more, deeper down.

Validate a single skill while iterating:

```bash
skill-validator check --strict rust-conventions
```

Check the external links, which needs the network:

```bash
task links
```

`check` reports four groups — `structure`, `links` (relative ones only),
`content`, `contamination` — and `--only` / `--skip` select among them. Two
failures come up often:

- **`parsing frontmatter YAML: mapping values are not allowed in this
  context`** — the `description` is a plain scalar rather than `>-`; see
  [Adding or editing a skill](#adding-or-editing-a-skill).
- **`SKILL.md body is N tokens (spec recommends < 5000)`** — split the skill
  into a sibling skill; see
  [Adding or editing a skill](#adding-or-editing-a-skill).

## Pre-commit hooks

`task setup` installs the hooks; they must pass before you push.

```bash
task lint
```

```bash
pre-commit run <hook-id> --all-files
```

The hooks are listed in [.pre-commit-config.yaml](.pre-commit-config.yaml);
most are formatters or checks that name the file to fix. These need more:

| Hook | What it checks | How to fix |
| --- | --- | --- |
| `yamllint` | YAML style, per [.yamllint.yaml](.yamllint.yaml), with `--strict` so warning-level rules fail too | Fix the finding; block style only, no `---` opening a file |
| `actionlint` | Workflow files are valid | Fix the expression or key it names |
| `skill-validator` | Skill structure, relative links, content, contamination, with the `skill-validator` mise installs | See [Running the tests](#running-the-tests) |
| `mise-fmt` | `mise.toml` is formatted, with the `mise` on `PATH` | Re-run: it rewrites the file |
| `no-co-authors` (`commit-msg` stage) | No `Co-Authored-By:` trailer or `Generated with` line in the commit message. Runs on `git commit` only: `pre-commit run --all-files`, and so CI, skips it | Rewrite the message; a commit has one author |

`--no-verify` and `SKIP=` are not the fix. A red hook is a real finding: fix
the content, or change the hook configuration in the same pull request and say
why. The same hooks run in CI, so skipping locally only moves the failure
somewhere slower.

## Continuous integration

| Workflow | What it does | Reproduce locally |
| --- | --- | --- |
| [`quality.yaml`](.github/workflows/quality.yaml) | Every job installs its tools with mise. `pre-commit` job: `task lint`. `skills` job: [groupbees/skill-action](https://github.com/groupbees/skill-action) runs `skill-validator check` and `pollen validate` on every skill, at the skill-validator version `mise.toml` pins, then `task links`; skill-validator runs with `--emit-annotations`, so its findings land on their line in the diff | `task lint`, `skill-validator check --strict --max-depth 1 .`, `task links` and `pollen validate` on a `pollen.yaml` selecting `.` (`repo: local`) |
| [`renovate.yaml`](.github/workflows/renovate.yaml) | Weekly self-hosted Renovate run on [renovate.json](renovate.json); `workflow_dispatch` takes a `dryRun` and a `logLevel` | `workflow_dispatch` with `dryRun` |

The `pre-commit` and `skills` checks are required to merge into `main`. The
weekly run is for the external links: a documentation URL dies without any file
here changing.

The external-link check is not a pre-commit hook because it needs the network —
a gate that fails on a train is a gate people learn to bypass.

`quality` needs no secret and only reads the repository, so it runs the same
on a fork's pull request. `renovate` writes with a `RENOVATE_TOKEN` secret, a
token allowed to push branches and open pull requests here: a pull request
opened with `GITHUB_TOKEN` would not trigger `quality`.

Renovate keeps every pin current: the action SHA pins, the pre-commit hook
revisions, and the tool versions in `mise.toml` and `mise.lock`. Pins are SHAs
and tags can move, so a bot bumps them rather than a person remembering to;
grouping folds the minor and patch bumps into one pull request per ecosystem,
each major gets its own, and nothing is automerged.

## Submitting a change

- Commit subjects are imperative, lowercase, with an optional `area:` prefix —
  read `git log --oneline` and follow what is there.
- Pull requests are squash-merged, so the pull request title becomes the
  commit subject on `main`: write it in the same style.
- A pull request needs green CI and no `TODO` left behind in a committed file:
  work that remains goes in an issue.
