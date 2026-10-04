# Agent skills and Claude Code configuration

Personal engineering conventions, packaged as [Agent Skills](https://agentskills.io),
plus the global instructions for [Claude Code](https://claude.com/claude-code).

## Description

Each convention topic (Python, Rust, Helm, Docker, CI, YAML, logging, …) is a
skill in `skills/<name>/SKILL.md` that loads on demand when its triggers match,
so a session only carries the conventions that apply to the work in front of
it. The skills follow the open specification, so any client that reads it —
Claude Code, Cursor, Codex, Gemini CLI, Copilot, OpenCode, … — can use them.

[`CLAUDE.md`](CLAUDE.md) holds the rules Claude Code applies to every project
unless a project-level `CLAUDE.md` overrides one. It is specific to Claude Code,
and the repository doubles as that tool's `~/.claude` directory.

There is nothing to build or run: the repository is Markdown that a client
reads.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the design and the reasoning behind it.

## Getting started

### Prerequisites

- `git`.
- An Agent Skills client, such as
  [Claude Code](https://docs.claude.com/en/docs/claude-code).
- [pollen](https://github.com/groupbees/pollen), to deploy the skills into a
  client's directories. Not needed to use the repository as `~/.claude`.

### Installation

#### Any Agent Skills client, with pollen

[pollen](https://groupbees.github.io/pollen/) deploys skills from a git
repository into the directories the clients read. This `pollen.yaml` installs
every skill from this repository for the current user, in both Claude Code's
directory and the cross-client `~/.agents/skills/`:

```yaml
targets:
  - ~/.claude/skills
  - ~/.agents/skills
repos:
  - repo: https://github.com/leroyguillaume/claude
    revision: main
    paths:
      - path: skills/
```

```sh
pollen update
```

This installs the skills only, not `CLAUDE.md`.

#### Claude Code, as `~/.claude`

Claude Code reads its configuration from `~/.claude`. To use this repository
as that directory, skills and `CLAUDE.md` together, move any existing
`~/.claude` aside first, then clone:

```bash
mv ~/.claude ~/.claude.bak
```

```bash
git clone git@github.com:leroyguillaume/claude.git ~/.claude
```

The [`.gitignore`](.gitignore) is an allow-list: it ignores everything except
what the repository versions, so Claude Code's sessions, caches and history
land beside the tracked files without showing up in `git status`.

To keep an existing `~/.claude` and put it under version control instead,
initialise it in place:

```bash
cd ~/.claude
git init
git remote add origin git@github.com:leroyguillaume/claude.git
git fetch origin
git checkout -f main
```

### Configuration

- **pollen targets**: drop the `targets` block to install into the current
  project instead (`.claude/skills/` and `.agents/skills/`).
- **Another client's global rules**: `CLAUDE.md` is only read by Claude Code.
  Copy the rules you want into that client's own instructions file (such as
  `AGENTS.md`).

### Usage

The skills take effect the next time a client starts.

- **Skills** load automatically when their triggers match. Each `SKILL.md`
  frontmatter says when to load (`TRIGGER`) and when to skip (`SKIP`). Most
  clients also let you invoke one explicitly — `/<skill-name>` in Claude Code.
- **Global rules** in [`CLAUDE.md`](CLAUDE.md) apply unconditionally in Claude
  Code.

To pull new revisions with pollen — skills removed here are removed from the
targets too:

```sh
pollen update
```

As `~/.claude`:

```bash
git -C ~/.claude pull --ff-only
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
