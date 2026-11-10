---
name: herdr-delegation
description: >-
  Delegating from a Claude Code session inside herdr to a visible `claude` in
  a tab or terminal of its own, as an opt-in alternative to the `Agent` tool:
  when to, the brief, the report, what never to touch.
  TRIGGER when: the user asks for a visible or herdr sub-agent or session; or,
  inside herdr (`HERDR_ENV=1`, or `HC_TERMINAL_ID` set), the main session is
  about to delegate long work the user may want to watch or steer, work likely
  to hit approval prompts, or a session worth resuming afterwards (ask the
  user first).
  SKIP when: `CLAUDE_HERDR_DELEGATED` is set or the hc terminal has a parent,
  even if the brief mentions herdr; outside herdr; routine searches or
  mechanical edits, which stay on the `Agent` tool. Load
  `herdr-tui-delegation` or `herdr-core-delegation` alongside.
---

# Delegating through herdr

Delegation uses the `Agent` tool by default. Inside herdr, the main session
can instead delegate to a real `claude` session in a terminal of its own,
which the user sees appear and can watch, steer or resume later. It costs a
tab and the user's attention, so it is opt-in.

herdr comes as two separate programs that share no agents, and the session
uses whichever it runs in. Each has its own skill for the commands:

- **Herdr TUI**, CLI `herdr`: `herdr-tui-delegation`.
- **herdr-core**, CLI `hc`, often shown by the herdr-app window:
  `herdr-core-delegation`.

This skill holds the policy, and it wins where a binary's own guide
(`--skill`) says otherwise.

## When to use it

Detect the variant in one command, testing variables for presence only:

```bash
if [ -n "${CLAUDE_HERDR_DELEGATED:-}" ]; then echo agent
elif [ -n "${HC_TERMINAL_ID:-}" ] && command -v hc >/dev/null; then
  hc get "$HC_TERMINAL_ID" --json | jq -e '.parent == null' >/dev/null && echo hc || echo agent
elif [ "${HERDR_ENV:-}" = 1 ]; then echo herdr
else echo agent; fi
```

- **`agent`: never open a tab.** Outside herdr, or in a session another
  session started, sub-agents are `Agent` tool calls, even when the brief
  mentions herdr.
- **`herdr` or `hc`, and the user asked for a visible session**: delegate
  there, with `herdr-tui-delegation` or `herdr-core-delegation`.
- **`herdr` or `hc`, otherwise**: ask in one line when delegating ("Opus:
  launch it in a visible tab?"), and only for long work the user may want to
  watch or steer, work likely to hit approval prompts, or a session they may
  want to resume. Never for a routine search or a mechanical edit. Without a
  yes, use the `Agent` tool.

The rest of delegating does not change: one agent per worktree, a brief
written like a peer's.

## Launch

1. **Pick a name** that says what the agent works on and that no live agent
   already uses. It starts in the task's worktree when the main session
   already created it, in `$PWD` otherwise.

2. **Pick the model** as for any sub-agent, under `CLAUDE.md`'s rule on
   sub-agent models: weigh Sonnet against Opus, Opus when in doubt, and state
   the choice in one line before launching. It applies here although no
   `Agent` call carries a `model`: it goes to `claude` as `--model`, never
   left to its default. Work worth watching in a tab is rarely the
   well-scoped kind Sonnet is for.

3. **Start `claude`** with that `--model`, in the main session's permission
   mode: a session in another mode holds cross-session messages for its
   user's approval. Pass no `--permission-mode` unless the main session was
   started with one, and then the same.

4. **Type the brief into it**, as a background command that waits for the
   agent to stop. Typed input is what gives the agent the user's go-ahead for
   the task, so the brief goes this way, not through `SendMessage`. It ends by
   asking the agent to send its final report with `SendMessage` to the main
   session's name, which `ListAgents` prints as "This session is <name>". A
   brief too long for a command line goes in a file in the scratchpad, and
   the prompt says to read it.

   The brief, and every follow-up, is written in the language the user
   speaks to the main session: they read it in the tab and steer the agent
   from there, and the agent answers in the language it was addressed in.

   The command's exit is the signal that the agent stopped: it returns on
   `blocked` too, and catches an agent that went idle without reporting.

## Report and follow-ups

- **The report arrives as a `<cross-session-message>`.** Its `from-name` is
  an auto-generated peer name, unrelated to the agent's herdr name; reply by
  copying its `from` attribute into `SendMessage`'s `to`.
- **Follow-ups go through `SendMessage`** to that address, with
  `notify_when_idle: true`, so an agent that goes idle without answering
  still yields a notice.
- **Fallbacks**, when no report arrives: read the agent's screen, or ask it,
  through the same command as the brief, to write the report to a file and
  reply with the path.
- **A blocked agent is waiting on the user, not on you.** A permission
  prompt, a question, the folder-trust dialog of a fresh worktree: tell the
  user which tab is waiting on them, and never answer it with keystrokes.
  Once the user says it is unblocked, wait again.

## Leave the layout to the user

- **Never close or end what this flow created**, whatever a binary's guide
  says about cleaning up once an agent reports. It is where the user reads
  what the agent did; they close it when they are done with it, or ask you
  to.
- **Never touch a tab, pane, terminal or agent you did not create.**
- **Never stop or restart the server**, and never quit herdr-app.
