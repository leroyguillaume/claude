# Agent skills and Claude Code configuration

Personal engineering conventions, packaged as [Agent Skills](https://agentskills.io),
plus the global instructions for [Claude Code](https://claude.com/claude-code).

## Description

Each convention topic (Python, Rust, Helm, Docker, CI, YAML, logging, …) is a
skill in `skills/<name>/SKILL.md` that loads on demand when its triggers match,
so a session only carries the conventions that apply to the work in front of
it. A skill can also be a workflow that runs only when asked for by name:
`council` puts a high-stakes decision through independent advisors and a
verdict. The skills follow the open specification, so any client that reads
it — Claude Code, Cursor, Codex, Gemini CLI, Copilot, OpenCode, … — can use
them.

[`CLAUDE.md`](CLAUDE.md) holds the rules Claude Code applies to every project
unless a project-level `CLAUDE.md` overrides one. It is specific to Claude Code,
and the repository doubles as that tool's `~/.claude` directory. It is written
for one person's machines and addresses that person directly, so adopting it
means rewriting it; the skills are self-contained and install on their own.

Two shell scripts complete the Claude Code setup:

- [`statusline-command.sh`](statusline-command.sh) is Claude Code's status
  line. It prints three lines: the model with a bar of the context window
  used, then a bar of the 5-hour rate limit with its reset time, and a bar of
  the 7-day rate limit with its reset day and time. A rate-limit line is
  omitted when Claude Code reports no such limit. Bars turn yellow from 50%
  and red from 80%.
- [`hooks/herdr-tab-title.sh`](hooks/herdr-tab-title.sh) is a `Stop` hook for
  sessions run in [herdr](https://herdr.dev): it renames the tab after the
  terminal title Claude Code gives the session, so a tab reads "Fix the flaky CI job"
  instead of "2". It only renames a tab that holds that one pane and
  still has herdr's default numeric label, so a label someone chose is never
  overwritten, and a renamed tab keeps its first title. It does nothing in a
  subagent, outside herdr, or before the session has a title of its own.

Everything else is Markdown that a client reads; there is nothing to build.

## Getting started

### Prerequisites

- `git`.
- [`jq`](https://jqlang.org/download/), for the status line; `jq` and herdr
  for the tab-title hook.
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
land beside the tracked files without showing up in `git status`. A deny-list
would have to grow every time Claude Code writes a new kind of state, and the
cost of forgetting one is a committed credential.

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

To show the status line, point Claude Code at the script in `settings.json`,
which the repository does not version:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

To name herdr tabs after their session, register the hook under `Stop` in
the same file. It runs in the background, so it never delays the end of a
turn:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh ~/.claude/hooks/herdr-tab-title.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

Both scripts sit in `~/.claude` when the repository is cloned there; otherwise
use the path of your copy.

Claude Code lists every skill's name and description to the model within a
size budget. The descriptions of these skills together exceed the default, and
past it the least-used skills are listed without their description, so the
model sees less of when to load them. This value makes room for all of them:

```json
{
  "skillListingBudgetFraction": 0.02
}
```

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
