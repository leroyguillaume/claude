---
name: herdr-delegation
description: >-
  Delegating from a Claude Code session inside herdr to a visible `claude` in
  a herdr tab of its own, as an opt-in alternative to the `Agent` tool.
  TRIGGER when: the user asks for a visible or herdr sub-agent or session; or,
  with `HERDR_ENV=1`, the main session is about to delegate long work the user
  may want to watch or steer, work likely to hit approval prompts, or a
  session worth resuming afterwards (ask the user first).
  SKIP when: `CLAUDE_HERDR_DELEGATED` is set, even if the brief mentions
  herdr; outside herdr; routine searches or mechanical edits, which stay on
  the `Agent` tool.
---

# Delegating through herdr

Delegation uses the `Agent` tool by default. Inside herdr, the main session
can instead delegate to a real `claude` session in a tab of its own, which the
user sees appear and can watch, steer or resume later. It costs a tab and the
user's attention, so it is opt-in.

The installed `herdr` binary is the authority on its syntax: `herdr --skill`
for the full guide, `herdr tab <command> --help` and
`herdr agent <command> --help` for one command. This skill holds the policy.

## When to use it

Check both variables in one command, for presence only:

```bash
if [ "${HERDR_ENV:-}" = 1 ] && [ -z "${CLAUDE_HERDR_DELEGATED:-}" ]; then echo herdr; else echo agent; fi
```

- **`agent`: never open a tab.** Outside herdr, or in a session started by
  this flow (its tab carries `CLAUDE_HERDR_DELEGATED=1`), sub-agents are
  `Agent` tool calls, even when the brief mentions herdr.
- **`herdr`, and the user asked for a visible session**: use a tab.
- **`herdr`, otherwise**: ask in one line when delegating ("Opus: launch it
  in a visible tab?"), and only for long work the user may want to watch or
  steer, work likely to hit approval prompts, or a session they may want to
  resume. Never for a routine search or a mechanical edit. Without a yes,
  use the `Agent` tool.

The rest of delegating does not change: one agent per worktree, a brief
written like a peer's, and the model (`sonnet` or `opus`) chosen on purpose
and named in the message that launches it.

## Launch

1. **Pick a name** that says what the agent works on and that
   `herdr agent list` does not already show.

2. **Open a tab** in the current workspace, labelled with that name, with the
   marker set and the user's focus kept where it is:

   ```bash
   herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" \
     --label fix-login-timeout --env CLAUDE_HERDR_DELEGATED=1 --no-focus
   ```

   `--cwd` is the task's worktree when the main session already created it,
   `$PWD` otherwise. The tab's pane ID is `.result.root_pane.pane_id`.

3. **Start `claude` in that pane**:

   ```bash
   herdr agent start fix-login-timeout --kind claude --pane <pane-id> -- --model sonnet
   ```

   It runs in the main session's permission mode: a session in another mode
   holds cross-session messages for its user's approval. Pass no
   `--permission-mode` unless the main session was started with one, and
   then the same.

4. **Type the brief into it**, as a background command:

   ```bash
   herdr agent prompt fix-login-timeout "<brief>" --wait
   ```

   Typed input is what gives the agent the user's go-ahead for the task, so
   the brief goes this way, not through `SendMessage`. It ends by asking the
   agent to send its final report with `SendMessage` to the main session's
   name, which `ListAgents` prints as "This session is <name>". A brief too
   long for a command line goes in a file in the scratchpad, and the prompt
   says to read it.

   The brief, and every follow-up, is written in the language the user
   speaks to the main session: they read it in the tab and steer the agent
   from there, and the agent answers in the language it was addressed in.

   The command's exit is the signal that the agent stopped: it returns on
   `blocked` too, and catches an agent that went idle without reporting.
   `--wait` first waits for the agent to start working, so it cannot match
   the idle state the agent has not left yet.

## Report and follow-ups

- **The report arrives as a `<cross-session-message>`.** Its `from-name` is
  an auto-generated peer name, unrelated to the herdr agent name; reply by
  copying its `from` attribute into `SendMessage`'s `to`.
- **Follow-ups go through `SendMessage`** to that address, with
  `notify_when_idle: true`, so an agent that goes idle without answering
  still yields a notice.
- **Fallbacks**, when no report arrives: `herdr agent read <name> --source
  recent-unwrapped`, or ask it through `herdr agent prompt` to write the
  report to a file and reply with the path.
- **A blocked agent is waiting on the user, not on you.** When `agent start`
  returns `agent_not_ready` or a wait returns `blocked` (a permission prompt,
  a question, the folder-trust dialog of a fresh worktree), tell the user
  which tab is waiting on them. Never answer it with `send-keys`. Once the
  user says it is unblocked, wait again with `herdr agent wait <name>`.

## Leave the layout to the user

- **Never close a tab or pane this flow created.** It is where the user
  reads what the agent did; they close it when they are done with it.
- **Never touch a tab, pane or agent you did not create**, and never run
  `herdr server stop`.
