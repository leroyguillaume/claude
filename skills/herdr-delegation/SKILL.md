---
name: herdr-delegation
description: >-
  Delegating from a Claude Code session inside herdr to a visible `claude` in
  a tab or terminal of its own, one per topic when a request holds several:
  when to, where it opens, the brief, the report, when to close it, what never
  to touch.
  TRIGGER when: the user asks for a visible or herdr sub-agent or session; or,
  inside herdr (`HERDR_ENV=1`, or `HC_TERMINAL_ID` set), the main session has
  split a request into several non-trivial topics.
  SKIP when: a single topic, which the main session carries, or a trivial
  one; `CLAUDE_HERDR_DELEGATED` is set or the hc terminal has a parent, even
  if the brief mentions herdr; outside herdr. Load `herdr-tui-delegation` or
  `herdr-core-delegation` alongside.
---

# Delegating through herdr

`CLAUDE.md` splits a request into topics. Inside herdr, when a request holds
several non-trivial ones, each goes to a real `claude` session in a terminal
of its own, which the user sees appear and can watch, steer or resume later.
A single topic stays with the main session, and a trivial one is done inline
or by an `Agent` call: a tab costs the user's attention, and earns it only
where there is a topic of its own to follow.

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
- **`herdr` or `hc`, and several non-trivial topics** — named by the request
  or surfaced by the look before deciding, such as a dependabot PR that
  fails: one visible session per topic, with `herdr-tui-delegation` or
  `herdr-core-delegation`, without asking.
- **`herdr` or `hc`, otherwise**: no tab. The main session carries a single
  topic itself, with `Agent` calls where they pay, and does a trivial one
  inline or through an `Agent` call.

A session per topic matches how the user follows the work: each topic is
steered, reviewed and followed up on its own, in its tab, while the main
session stays free to dispatch the next. A topic that ends in a PR keeps its
tab as long as the PR and closes it at the merge (below). Review comments and
a red CI land on the same branch, so the same session picks them up.
`git push` and `gh pr create` ask for approval, which the user answers in the
tab. And a `claude` session can launch `Agent` sub-agents of its own, which
an `Agent` sub-agent cannot, so a topic that turns out long splits from there.

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
   left to its default.

4. **Start `claude`** with that `--model`, in the main session's permission
   mode: a session in another mode holds cross-session messages for its
   user's approval. Pass no `--permission-mode` unless the main session was
   started with one, and then the same.

5. **Type the brief into it**, as a background command that waits for the
   agent to stop. Typed input is what gives the agent the user's go-ahead for
   the task, so the brief goes this way, not through `SendMessage`. It ends by
   asking the agent to stop every background command and monitor it started,
   then send its final report with `SendMessage` to the main session's name,
   which `ListAgents` prints as "This session is <name>". A
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
  still yields a notice. Once its tab is closed (below), a follow-up — a
  review comment, a red CI — reopens it instead: a new tab in the same
  worktree, running `claude --continue` with the same `--model`, which
  resumes the last conversation held there, and the follow-up typed in as its
  brief.
- **Fallbacks**, when no report arrives: read the agent's screen, or ask it,
  through the same command as the brief, to write the report to a file and
  reply with the path.
- **A blocked agent is waiting on the user, not on you.** A permission
  prompt, a question, the folder-trust dialog of a fresh worktree: tell the
  user which tab is waiting on them, and never answer it with keystrokes.
  Once the user says it is unblocked, wait again.

## Leave the layout to the user

- **Close what this flow created once it is done**, on either condition:
  - **its PR is merged** (`gh pr view <branch> --json state` says
    `MERGED`): in the post-merge cleanup, before removing the worktree and
    branch, since the agent's cwd lives in the worktree;
  - **it sits with nothing left to do**: its final report has arrived and
    reached the user, it is idle — never `blocked`, which waits on the user —
    and the report leaves no background command or monitor running.

  Nothing else is a reason: not a report while the agent still works, not an
  idle agent whose report never came. The transcript stays on disk, which is
  what lets a follow-up reopen it.
- **Never touch a tab, pane, terminal or agent you did not create.**
- **Never stop or restart the server**, and never quit herdr-app.
