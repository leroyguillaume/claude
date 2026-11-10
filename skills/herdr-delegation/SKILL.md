---
name: herdr-delegation
description: >-
  Delegating from a Claude Code session inside herdr to a visible `claude` in
  a tab or terminal of its own instead of the `Agent` tool, for a PR in
  several pieces that takes judgement: when to, where it opens, the brief, the
  report, when to close it, what never to touch.
  TRIGGER when: the user asks for a visible or herdr sub-agent or session; or,
  inside herdr (`HERDR_ENV=1`, or `HC_TERMINAL_ID` set), the main session is
  about to delegate a PR that spans several distinct pieces and gets Opus.
  SKIP when: the deliverable is an answer, a targeted fix or a mechanical PR,
  which stay on the `Agent` tool; `CLAUDE_HERDR_DELEGATED` is set or the hc
  terminal has a parent, even if the brief mentions herdr; outside herdr.
  Load `herdr-tui-delegation` or `herdr-core-delegation` alongside.
---

# Delegating through herdr

Delegation uses the `Agent` tool by default. Inside herdr, a PR in several
pieces that takes judgement goes instead to a real `claude` session in a
terminal of its own, which the user sees appear and can watch, steer or
resume later. It costs a tab and the user's attention, so it is kept for that
work: everything else stays an `Agent` call.

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
- **`herdr` or `hc`, and the user asked for one or the other** — a visible
  session ("in a tab") or a sub-agent: that wins over the two rules below.
- **`herdr` or `hc`, a PR in several pieces, and Opus** — the request holds
  several distinct changes, or one task that splits into several pieces, and
  the model picked under `CLAUDE.md`'s rule is Opus: delegate to a visible
  session, with `herdr-tui-delegation` or `herdr-core-delegation`, without
  asking.
- **`herdr` or `hc`, otherwise**: use the `Agent` tool. That covers an
  answer — a search, a review, a diagnosis, a test run, a summary — and a PR
  that is one targeted change or mechanical work, even across many files:
  there is nothing in it to watch or steer.

A tab earns the user's attention where there is something to watch and
steer: a request in several pieces, on work that takes judgement, where an
agent can go astray partway. Both are known before the launch — the scope
from the request, the model from the choice stated before every launch —
unlike how long the work will run. Such work also fits a session of its own.
Its tab lives as long as the PR and closes at the merge (below). Review
comments and a red CI land on the same branch, so the same session picks
them up. `git push` and `gh pr create` ask for approval, which the user
answers in the tab. And a `claude` session can launch `Agent` sub-agents of
its own, which an `Agent` sub-agent cannot.

The rest of delegating does not change: one agent per worktree, a brief
written like a peer's.

## Launch

1. **Pick a name** that says what the agent works on and that no live agent
   already uses.

2. **Pick where it opens.** It starts in the task's worktree when the main
   session already created it, otherwise at the root of the repo the task is
   in: `$PWD` for the main session's own repo. Its tab goes in that repo's
   workspace (a space, in herdr-app), never taking the user's focus:

   - **The main session's repo**: the current workspace.
   - **Another repo**: the workspace with a pane in that repo or in one of
     its worktrees, which share its git common dir. A workspace may hold
     several repos. When several match, the one labelled with the repo's
     name, otherwise ask the user in one line. When none does, create one
     labelled with the repo's name.

3. **Pick the model** as for any sub-agent, under `CLAUDE.md`'s rule on
   sub-agent models: weigh Sonnet against Opus, Opus when in doubt, and state
   the choice in one line before launching. It applies here although no
   `Agent` call carries a `model`: it goes to `claude` as `--model`, never
   left to its default. Unless the user asked for the tab, it is Opus: work
   that gets Sonnet never opens one.

4. **Start `claude`** with that `--model`, in the main session's permission
   mode: a session in another mode holds cross-session messages for its
   user's approval. Pass no `--permission-mode` unless the main session was
   started with one, and then the same.

5. **Type the brief into it**, as a background command that waits for the
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

- **Close what this flow created only once its PR is merged**
  (`gh pr view <branch> --json state` says `MERGED`), and on no other
  condition: not when the agent reports, not when it goes idle. Do it in the
  post-merge cleanup, before removing the worktree and branch, since the
  agent's cwd lives in the worktree. With no PR, or one still open or closed
  unmerged, leave it: the user closes it, or asks you to. The transcript
  stays resumable with `claude --resume`.
- **Never touch a tab, pane, terminal or agent you did not create.**
- **Never stop or restart the server**, and never quit herdr-app.
