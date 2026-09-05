# Contributing

This repository holds personal Claude Code configuration: the global
instructions in `CLAUDE.md` and the convention skills under `skills/`. A change
here is almost always a Markdown edit. Open an issue or a pull request on
<https://github.com/leroyguillaume/claude>; the short version is
`pre-commit run --all-files` must be green before you push.

See [README.md](README.md#install) for using this repository as your Claude
Code home directory.

## Development setup

Two tools are needed beyond `git`:

- [pre-commit](https://pre-commit.com) 4.x — runs the gate.
- [skill-validator](https://github.com/agent-ecosystem/skill-validator) 1.6.x —
  validates `skills/*/SKILL.md` structure, links, content and cross-language
  contamination.

`pre-commit` installs the linters it needs into its own environments, but two
of its hooks (`actionlint`, `skill-validator`) are built from source, so a Go
toolchain has to be on `PATH`. Installing `skill-validator` yourself as well is
worth it: running it directly gives faster feedback than going through the
hook.

**macOS**

```bash
brew install pre-commit go agent-ecosystem/tap/skill-validator
```

**Linux**

```bash
pipx install pre-commit
```

```bash
go install github.com/agent-ecosystem/skill-validator/cmd/skill-validator@v1.6.1
```

Go itself comes from your distribution (`apt install golang-go`,
`pacman -S go`, `dnf install golang`) or from
<https://go.dev/doc/install>.

Then, from a fresh clone:

```bash
pre-commit install
```

The setup is good when this is green:

```bash
pre-commit run --all-files
```

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

It reports four groups — `structure`, `links`, `content`, `contamination` —
and `--only` / `--skip` select among them. Two failures come up often:

- **`parsing frontmatter YAML: mapping values are not allowed in this
  context`** — the `description` is a multi-line plain scalar containing a
  `:`, which YAML cannot parse. Write it as a folded block scalar
  (`description: >-`), as every skill in `skills/` does.
- **`SKILL.md body is N tokens (spec recommends < 5000)`** — the skill has
  grown past what is loaded into context comfortably. Split it into a second
  skill with its own `TRIGGER`, rather than moving prose into `references/`:
  a sibling skill is loaded automatically when its triggers match, whereas a
  `references/` file is only read if something opens it.

A new skill needs frontmatter with `name`, a `description` carrying `TRIGGER` /
`SKIP` guidance, and an entry in the "Conventions (load on demand)" section of
[CLAUDE.md](CLAUDE.md).

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
| `skill-validator` | Skill structure, links, content, contamination | See "Running the tests" above |

`--no-verify` and `SKIP=` are not the fix. A red hook is a real finding: fix
the content, or change the hook configuration in the same pull request and say
why. The same hooks run in CI, so skipping locally only moves the failure
somewhere slower.

## Continuous integration

| Workflow | Triggers on | What it does | Reproduce locally |
| --- | --- | --- | --- |
| [`quality.yaml`](.github/workflows/quality.yaml) | push to `main`, every PR, weekly | `pre-commit run --all-files`; a second job re-runs `skill-validator` with `--emit-annotations` so findings land on the diff, then checks the external links | `pre-commit run --all-files` and `skill-validator validate links skills/` |
| [`security.yaml`](.github/workflows/security.yaml) | push to `main`, every PR, weekly | `trivy fs` over the checkout (vulnerabilities, secrets, misconfiguration), blocking on `HIGH`/`CRITICAL`; uploads SARIF to code scanning | `trivy fs .` |

Both workflows are blocking, and both re-run weekly for the same reason: a
vulnerability is disclosed, and a documentation URL dies, without any file here
changing. A run on merge day only reports what was true that day.

The external-link check is not a pre-commit hook because it needs the network —
a gate that fails on a train is a gate people learn to bypass.

Neither workflow needs a secret: `GITHUB_TOKEN` covers the SARIF upload, so
they run identically on a fork's pull request.

[`dependabot.yaml`](.github/dependabot.yaml) opens weekly grouped pull requests
for the action SHA pins and the pre-commit hook revisions. They are never
automerged.

## Submitting a change

- Commit subjects are imperative, lowercase, with an optional `area:` prefix —
  read `git log --oneline` and follow what is there.
- Update `CLAUDE.md`'s skill index in the same change that adds or renames a
  skill.
- A pull request needs green CI and no `TODO` left behind in a committed file:
  work that remains goes in an issue.
