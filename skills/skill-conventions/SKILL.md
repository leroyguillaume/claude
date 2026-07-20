---
name: skill-conventions
description: Conventions for writing Claude Code skills in this setup (one
  topic per skill, trigger-bearing description, terse imperative body with
  before/after examples, registered in the global `CLAUDE.md` index).
  TRIGGER when: creating or editing any skill under `~/.claude/skills/` or a
  project's `.claude/skills/`; writing or reviewing a `SKILL.md` frontmatter
  description; user asks how to write/structure a skill, why a skill did or
  didn't auto-load, or where a new rule should live (CLAUDE.md vs skill).
  SKIP when: merely invoking or following an existing skill without changing
  it, or the question is about plugins/marketplaces rather than skill content.
---

# Writing skills

Applies to every skill in `~/.claude/skills/` and in project `.claude/skills/`
directories. Skills are written in English, like READMEs.

## Where a rule lives

- **One directory per skill, one topic per skill.** `<name>/SKILL.md`, with a
  kebab-case directory name identical to the frontmatter `name:`. Conventions
  skills follow the `<topic>-conventions` pattern. A skill that covers two
  technologies is two skills.
- **`CLAUDE.md` holds unconditional guardrails; skills hold the concrete
  "how".** If a rule only matters when a certain kind of file or task shows
  up, it belongs in a skill. If missing it would be dangerous even when no
  skill loads, it belongs in `CLAUDE.md` — as a short negative guardrail, not
  a tutorial.
- **Register every new skill in the `CLAUDE.md` "Conventions (load on
  demand)" list**, in the same change: bold name plus a one-line summary of
  the memorable specifics, matching the existing entries' style.

## The description is the trigger

The body only loads when the description matches the situation — write the
description as if it were the only part the model will ever see.

- **Three parts, always:** a one-sentence summary with the punchline rule in
  parentheses, then `TRIGGER when:`, then `SKIP when:`. Write

  ```yaml
  description: YAML formatting conventions (block style only, no flow style).
    TRIGGER when: editing or creating any `.yaml`/`.yml` file; …
    SKIP when: no YAML is being written or edited and …
  ```

  not `description: Conventions for YAML.` — a description without explicit
  trigger conditions never fires when it should.
- **Triggers are concrete, not thematic.** Name file extensions, commands,
  API endpoints, env-var patterns, and user-question phrasings ("which model
  should I use") — not vague topics ("when doing DevOps work").
- **`SKIP when:` lists the nearest tempting-but-wrong cases**, the situations
  that look adjacent but must not load the skill (see `ollama-conventions`
  skipping hosted providers).

## Body style

- **H1 title, then one sentence saying where the skill applies.** No preamble.
- **Every rule is a bullet that leads with the rule in bold, imperative
  mood**, followed by the *why* in a clause or short sentence. If a rule is
  non-negotiable, say so in the rule itself.
- **Show before/after for anything syntactic:** a fenced snippet of the right
  form, then "not `<wrong form>`" inline. A rule without a concrete example
  is a rule that gets argued with.
- **Keep the whole file to a screen or two.** It is injected into context on
  every trigger; brevity is a feature. Move rarely-needed reference material
  to extra files in the skill directory and point to them from the body.
- **Restate, don't re-derive.** When a cross-cutting rule needs
  language-specific mechanics, the language skill restates only the mechanics
  and names the cross-cutting skill as canonical (as `rust-conventions` does
  for logging). Never copy a full rule between skills — drift is guaranteed.

## Anti-patterns

- A `description:` with no `TRIGGER`/`SKIP` clauses.
- Restating global `CLAUDE.md` rules in a body — reference them ("per global
  rules") instead.
- A mega-skill spanning several technologies or concerns.
- Rules with no example, or examples with no rule.
- Reference files that duplicate the `SKILL.md` instead of extending it.
