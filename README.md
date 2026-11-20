# skills

Personal engineering conventions, packaged as [Agent Skills](https://agentskills.io).

## Description

Each convention topic (Python, Rust, Helm, Docker, CI, YAML, logging, …) is a
skill in `<name>/SKILL.md` that loads on demand when its triggers match, so a
session only carries the conventions that apply to the work in front of it. A
skill can also be a workflow that runs only when asked for by name: `council`
puts a high-stakes decision through independent advisors and a verdict. The
skills follow the open specification, so any client that reads it — Claude
Code, Cursor, Codex, Gemini CLI, Copilot, OpenCode, … — can use them.

The skills that drive the client itself — delegating to a session in a herdr
tab, splitting a topic across sub-agents — launch the client they run in:
`claude` from Claude Code, `opencode` from OpenCode.

The global instructions that go with them, for Claude Code and OpenCode, live
in [claude-config](https://github.com/leroyguillaume/claude-config). Every
skill stands on its own without them.

Everything here is Markdown that a client reads; there is nothing to build.

## Getting started

### Prerequisites

- `git`.
- An Agent Skills client, such as
  [Claude Code](https://docs.claude.com/en/docs/claude-code) or
  [OpenCode](https://opencode.ai/docs/).
- On Windows, [Git for Windows](https://gitforwindows.org): the commands in
  the skills are bash, and run in its Git Bash.
- [pollen](https://github.com/groupbees/pollen), to deploy the skills into
  several clients' directories. Not needed for a clone in `~/.claude/skills`.

### Installation

#### Claude Code and OpenCode, as `~/.claude/skills`

Claude Code reads the user's skills from `~/.claude/skills`, and OpenCode
reads that directory too. Clone the repository there:

```bash
git clone git@github.com:leroyguillaume/skills.git ~/.claude/skills
```

When `~/.claude/skills` already exists — Claude Code mirrors the claude.ai
account's skills into its `synced/` directory, which the repository ignores —
initialise it in place instead:

```bash
cd ~/.claude/skills
git init
git remote add origin git@github.com:leroyguillaume/skills.git
git fetch origin
git checkout -f main
```

#### Any Agent Skills client, with pollen

[pollen](https://groupbees.github.io/pollen/) deploys skills from a git
repository into the directories the clients read. This `pollen.yaml` installs
every skill for the current user, in both Claude Code's directory and the
cross-client `~/.agents/skills/`:

```yaml
targets:
  - ~/.claude/skills
  - ~/.agents/skills
repos:
  - repo: https://github.com/leroyguillaume/skills
    revision: main
    paths:
      - path: .
```

```sh
pollen update
```

### Configuration

Drop the `targets` block of the `pollen.yaml` to install into the current
project instead (`.claude/skills/` and `.agents/skills/`).

The descriptions of these skills together exceed Claude Code's default skill
listing budget; [claude-config](https://github.com/leroyguillaume/claude-config#configuration)
says how to raise it.

### Usage

The skills take effect the next time a client starts. They load
automatically when their triggers match: each `SKILL.md` frontmatter says when
to load (`TRIGGER`) and when to skip (`SKIP`). Most clients also let you
invoke one explicitly — `/<skill-name>` in Claude Code.

To pull new revisions in a clone:

```bash
git -C ~/.claude/skills pull --ff-only
```

With pollen — skills removed here are removed from the targets too:

```sh
pollen update
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
