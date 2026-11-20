# Agent skills and Claude Code configuration

Personal engineering conventions, packaged as [Agent Skills](https://agentskills.io),
plus the global instructions for [Claude Code](https://claude.com/claude-code)
and [OpenCode](https://opencode.ai).

## Description

Each convention topic (Python, Rust, Helm, Docker, CI, YAML, logging, …) is a
skill in `skills/<name>/SKILL.md` that loads on demand when its triggers match,
so a session only carries the conventions that apply to the work in front of
it. A skill can also be a workflow that runs only when asked for by name:
`council` puts a high-stakes decision through independent advisors and a
verdict. The skills follow the open specification, so any client that reads
it — Claude Code, Cursor, Codex, Gemini CLI, Copilot, OpenCode, … — can use
them.

[`CLAUDE.md`](CLAUDE.md) holds the rules Claude Code and OpenCode apply to
every project unless a project's own instructions override one. The repository
doubles as Claude Code's `~/.claude` directory, which OpenCode reads too. It is
written for one person's machines and addresses that person directly, so
adopting it means rewriting it; the skills are self-contained and install on
their own. The skills that drive the client itself — delegating to a session
in a herdr tab, splitting a topic across sub-agents — launch the client they
run in: `claude` from Claude Code, `opencode` from OpenCode.

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
  still has herdr's default numeric label or the label the hook gave it for
  another session, so a label someone chose is never overwritten. A tab keeps
  the first title of each session and takes the next one's after a `/clear`:
  the hook records the label it sets and the session it set it for under
  `$XDG_STATE_HOME/claude/herdr-tab-title/` (`~/.local/state` by default). It
  does nothing in a subagent, outside herdr, or before the session has a title
  of its own.

Everything else is Markdown that a client reads; there is nothing to build.

## Getting started

### Prerequisites

- `git`.
- [`jq`](https://jqlang.org/download/), for the status line; `jq` and herdr
  for the tab-title hook.
- An Agent Skills client, such as
  [Claude Code](https://docs.claude.com/en/docs/claude-code) or
  [OpenCode](https://opencode.ai/docs/).
- On Windows, [Git for Windows](https://gitforwindows.org): the scripts and
  the commands in the skills are bash, and run in its Git Bash, with `jq` on
  its `PATH`.
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

#### OpenCode

OpenCode reads `~/.claude/CLAUDE.md` as its global rules when there is no
`~/.config/opencode/AGENTS.md`, and the skills in `~/.claude/skills/`. Clone
the repository as `~/.claude`, as above, and both apply.
`OPENCODE_DISABLE_CLAUDE_CODE=1` turns that off.

OpenCode's `task` tool takes no model: a sub-agent runs on the model of the
agent it is launched as. For the choice between Sonnet and Opus that
`CLAUDE.md` asks for at every launch, define one sub-agent per model in
`~/.config/opencode/opencode.json`, with ids from `opencode models`:

```json
{
  "agent": {
    "sonnet": {
      "mode": "subagent",
      "description": "Well-scoped work whose outcome is easy to check: search, mechanical edits, applying a known convention.",
      "model": "anthropic/claude-sonnet-5"
    },
    "opus": {
      "mode": "subagent",
      "description": "Work that needs judgement: design, debugging with no lead, review, trade-offs.",
      "model": "anthropic/claude-opus-5"
    }
  }
}
```

On Windows, OpenCode runs commands in PowerShell when it finds one. Point it
at Git Bash in the same file, so the skills' commands run:

```json
{
  "shell": "C:\\Program Files\\Git\\bin\\bash.exe"
}
```

### Configuration

- **pollen targets**: drop the `targets` block to install into the current
  project instead (`.claude/skills/` and `.agents/skills/`).
- **Another client's global rules**: `CLAUDE.md` is read by Claude Code, and
  by OpenCode from `~/.claude`. For any other client, copy the rules you want
  into its own instructions file (such as `AGENTS.md`).

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
size budget, a fraction of the model's context window. The descriptions of
these skills together exceed the default, and past it the least-used skills
are listed without their description, so the model sees less of when to load
them. Raise the fraction in `~/.claude/settings.json`:

```json
{
  "skillListingBudgetFraction": 0.02
}
```

The budget scales with the context window, so the fraction that fits depends
on the model. Run `/skill-doctor` in Claude Code to see what each skill costs
in the listing, and raise the fraction until it fits.

Claude Code ends commit messages with a co-author trailer and pull request
descriptions with a "Generated with" line; `CLAUDE.md` forbids both. An
instruction can lose to the harness's own, so turn them off at the source:

```json
{
  "attribution": {
    "commit": "",
    "pr": ""
  }
}
```

### Usage

The skills take effect the next time a client starts.

- **Skills** load automatically when their triggers match. Each `SKILL.md`
  frontmatter says when to load (`TRIGGER`) and when to skip (`SKIP`). Most
  clients also let you invoke one explicitly — `/<skill-name>` in Claude Code.
- **Global rules** in [`CLAUDE.md`](CLAUDE.md) apply unconditionally in Claude
  Code and OpenCode.

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
