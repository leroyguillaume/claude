# Claude Code configuration

Version-controlled personal configuration for [Claude Code](https://claude.com/claude-code).
This repository lives at `~/.claude` and tracks only the parts of that directory
worth sharing across machines: the global instructions (`CLAUDE.md`) and the
on-demand convention **skills**. Everything else Claude Code writes into
`~/.claude` (sessions, cache, history, telemetry, plugins, …) is deliberately
ignored.

## What's in here

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | Global, non-negotiable rules applied to **every** project unless a project-level `CLAUDE.md` overrides a specific rule. |
| `skills/<name>/SKILL.md` | Convention skills that load on demand, triggered by file paths or topics (Python, Rust, Helm, Docker, CI, YAML, logging, …). |

The `.gitignore` is allow-list based — it ignores `**` and then re-includes
`CLAUDE.md` and `skills/**/*.md`. If you add a new skill, it is picked up
automatically; runtime state never ends up in a commit.

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed.
- `git` to clone and update.

## Install

Claude Code reads its configuration from `~/.claude`. To use this repo as that
directory:

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

There is nothing to run — the configuration takes effect the moment Claude Code
starts in any project on the machine.

- **Global rules** in `CLAUDE.md` apply unconditionally (tests must exist,
  baseline pre-commit hooks, README kept current, rule-of-three for
  duplication, env-var naming, versioning policy, …).
- **Skills** load automatically when their triggers match. Each
  `skills/<name>/SKILL.md` starts with frontmatter describing when to load
  (`TRIGGER`) and when to skip (`SKIP`). You can also invoke one explicitly with
  `/<skill-name>` in a Claude Code session.

## Adding or editing a skill

1. Create `skills/<my-skill>/SKILL.md`.
2. Add YAML frontmatter with a `name`, a `description`, and clear `TRIGGER` /
   `SKIP` guidance so Claude knows when to load it:

   ```markdown
   ---
   name: my-skill
   description: One line on what this covers.
     TRIGGER when: <conditions that should load the skill>.
     SKIP when: <conditions where it is irrelevant>.
   ---

   # My skill

   The actual conventions go here.
   ```

3. Reference it from the "Conventions (load on demand)" section of `CLAUDE.md`
   if it should be discoverable from the top-level index.

## Updating

```bash
cd ~/.claude
git pull --ff-only
```

Commit changes to `CLAUDE.md` or any skill as you would any other repo; runtime
files stay ignored, so commits remain focused on configuration.
