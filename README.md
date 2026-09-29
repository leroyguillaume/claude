# Agent skills and Claude Code configuration

Personal engineering conventions, packaged as [Agent Skills](https://agentskills.io):
one `skills/<name>/SKILL.md` per topic (Python, Rust, Helm, Docker, CI, YAML,
logging, …), each loading on demand when its triggers match. The skills follow
the open specification, so any client that reads it — Claude Code, Cursor,
Codex, Gemini CLI, Copilot, OpenCode, … — can use them.

The repository also holds the global instructions for
[Claude Code](https://claude.com/claude-code), `CLAUDE.md`, and doubles as that
tool's `~/.claude` directory.

## What's in here

| Path | Purpose |
| --- | --- |
| `skills/<name>/SKILL.md` | Convention skills that load on demand, triggered by file paths or topics. Client-agnostic. |
| `CLAUDE.md` | Global, non-negotiable rules Claude Code applies to **every** project unless a project-level `CLAUDE.md` overrides a specific rule. |

The `.gitignore` is allow-list based — it ignores `**` and then re-includes
`CLAUDE.md` and `skills/**/*.md`. A new skill is picked up automatically;
Claude Code's runtime state never ends up in a commit.

## Requirements

- `git` to clone and update.
- An Agent Skills client, such as
  [Claude Code](https://docs.claude.com/en/docs/claude-code).
- [pollen](https://github.com/groupbees/pollen), to deploy the skills into
  another client.

## Install

### Any Agent Skills client, with pollen

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

Drop the `targets` block to install into the current project instead
(`.claude/skills/` and `.agents/skills/`). Re-run `pollen update` to pull new
revisions; skills removed here are removed from the targets too.

This installs the skills only. `CLAUDE.md` is specific to Claude Code; for
another client, copy the rules you want into its own instructions file (such
as `AGENTS.md`).

### Claude Code, as `~/.claude`

Claude Code reads its configuration from `~/.claude`. To use this repository
as that directory, skills and `CLAUDE.md` together:

```bash
# Back up an existing config first if you have one
mv ~/.claude ~/.claude.bak 2>/dev/null || true

git clone git@github.com:leroyguillaume/claude.git ~/.claude
```

Because the ignore rules only track `CLAUDE.md` and `skills/`, you can safely
keep using `~/.claude` as your live Claude Code directory — new sessions, cache,
and history land beside the tracked files without polluting `git status`.

Already running Claude Code from `~/.claude` and just want version control?
Initialise it in place instead of cloning:

```bash
cd ~/.claude
git init
git remote add origin git@github.com:leroyguillaume/claude.git
git fetch origin
git checkout -f main
```

## Usage

There is nothing to run — the skills take effect the next time a client
starts.

- **Skills** load automatically when their triggers match. Each
  `skills/<name>/SKILL.md` starts with frontmatter describing when to load
  (`TRIGGER`) and when to skip (`SKIP`). Most clients also let you invoke one
  explicitly — `/<skill-name>` in Claude Code.
- **Global rules** in `CLAUDE.md` apply unconditionally in Claude Code (tests
  must exist, baseline pre-commit hooks, README kept current, rule-of-three for
  duplication, env-var naming, versioning policy, …).

## Adding or editing a skill

1. Create `skills/<my-skill>/SKILL.md`.
2. Add YAML frontmatter with a `name`, a `description`, and clear `TRIGGER` /
   `SKIP` guidance so the client knows when to load it. The description is a
   folded block scalar (`>-`) because it embeds `TRIGGER when:` — a `:` inside
   a plain multi-line scalar is not valid YAML:

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

See [CONTRIBUTING.md](CONTRIBUTING.md) for validating a skill before pushing,
and [ARCHITECTURE.md](ARCHITECTURE.md) for why conventions live in skills and
what happens when one outgrows its token budget.

## Updating

With pollen, `pollen update`. As `~/.claude`:

```bash
cd ~/.claude
git pull --ff-only
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
