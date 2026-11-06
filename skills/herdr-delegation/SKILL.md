---
name: herdr-delegation
description: >-
  Delegating from a Claude Code session inside herdr: the sub-agent runs as a
  visible `claude` in a new herdr pane instead of through the `Agent` tool.
  TRIGGER when: the main session is about to delegate work or launch a
  sub-agent and `HERDR_ENV=1`.
  SKIP when: `CLAUDE_HERDR_DELEGATED` is set (a delegated session uses the
  `Agent` tool for its own sub-agents), or outside herdr.
---

# Delegating through herdr

Inside herdr, the main session delegates to a real `claude` session in a pane
of its own, so the user sees it appear and can watch it or talk to it. The
`Agent` tool runs in-process, with no terminal anyone can look at. Only the
first level is visible: a delegated session's own sub-agents are its business
and stay `Agent` tool calls.

The installed `herdr` binary is the authority on its syntax: `herdr --skill`
for the full guide, `herdr pane <command> --help` and
`herdr agent <command> --help` for one command. This skill holds the policy.

## Which path to take

Check both variables in one command, for presence only:

```bash
if [ "${HERDR_ENV:-}" = 1 ] && [ -z "${CLAUDE_HERDR_DELEGATED:-}" ]; then echo herdr; else echo agent; fi
```

- `herdr`: the main session, inside herdr. Delegate as below.
- `agent`: outside herdr, or a session started by this flow, whose pane
  carries `CLAUDE_HERDR_DELEGATED=1`. Use the `Agent` tool as usual.

The rest of delegating does not change: what is worth delegating, one agent
per worktree, a brief written like a peer's, and the model (`sonnet` or
`opus`) chosen on purpose and named in the message that launches it.

## Launch

1. **Pick the direction** from the calling pane's rect:

   ```bash
   herdr pane layout --pane "$HERDR_PANE_ID" \
     | jq --arg p "$HERDR_PANE_ID" '.result.layout.panes[] | select(.pane_id == $p).rect'
   ```

   The rect is in cells, which are about twice as tall as they are wide:
   `right` when the width is at least twice the height, `down` otherwise.

2. **Split the calling pane**, with the marker set and the user's focus kept
   where it is:

   ```bash
   herdr pane split --current --direction right --cwd "$PWD" \
     --env CLAUDE_HERDR_DELEGATED=1 --no-focus
   ```

   `--cwd` is the task's worktree when the main session already created it,
   `$PWD` otherwise. The new pane's ID is `.result.pane.pane_id`.

3. **Start `claude` in it**, under a name that says what it works on and
   that `herdr agent list` does not already show:

   ```bash
   herdr agent start fix-login-timeout --kind claude --pane <pane-id> -- --model sonnet
   ```

4. **Send the brief** as a background command, so the main session stays
   free to talk:

   ```bash
   herdr agent prompt fix-login-timeout "<brief>" --wait
   ```

   Its exit is the notification. `--wait` first waits for the agent to start
   working, then for it to settle; a separate `herdr agent wait` sent right
   after the prompt can match the idle state the agent has not left yet. Add
   `--timeout` only when the main session has to block on the result.

   The brief ends by asking the agent to write its final report to
   `<scratchpad>/<agent-name>-report.md`, in the main session's scratchpad,
   and to reply with that path and nothing else. A brief too long for a
   command line goes in a file in the scratchpad, and the prompt says to read
   it.

## The report comes back as a file

Read the file the agent named. A terminal scrape loses the start of a long
answer, and the report is the deliverable, so the file is asked for up front.
Fall back to `herdr agent read <name> --source recent-unwrapped` only when the
file is missing.

## While it runs

- **Follow-ups go through the pane**: `herdr agent prompt <name> "<message>"
  --wait`, in the background, where the `Agent` tool would use `SendMessage`.
- **A blocked agent is waiting on the user, not on you.** When `agent start`
  returns `agent_not_ready` or a wait returns `blocked` (a permission prompt,
  a question, the folder-trust dialog of a fresh worktree), tell the user
  which agent is waiting in its pane. Never answer it with `send-keys`. Once
  the user says it is unblocked, wait again with `herdr agent wait <name>`.

## Leave the layout to the user

- **Never close a pane this flow created.** It is where the user reads what
  the agent did; they close it when they are done with it.
- **Never touch a pane or an agent you did not create**, and never run
  `herdr server stop`.
