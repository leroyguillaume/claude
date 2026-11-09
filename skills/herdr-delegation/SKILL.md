---
name: herdr-delegation
description: >-
  Delegating from a Claude Code session inside herdr to a visible `claude` in
  a herdr tab or terminal of its own, through the legacy `herdr` CLI or
  herdr-core's `hc`, as an opt-in alternative to the `Agent` tool.
  TRIGGER when: the user asks for a visible or herdr sub-agent or session; or,
  inside herdr (`HERDR_ENV=1`, or `HC_TERMINAL_ID` set), the main session is
  about to delegate long work the user may want to watch or steer, work likely
  to hit approval prompts, or a session worth resuming afterwards (ask the
  user first).
  SKIP when: `CLAUDE_HERDR_DELEGATED` is set or the hc terminal has a parent,
  even if the brief mentions herdr; outside herdr; routine searches or
  mechanical edits, which stay on the `Agent` tool.
---

# Delegating through herdr

Delegation uses the `Agent` tool by default. Inside herdr, the main session
can instead delegate to a real `claude` session in a terminal of its own,
which the user sees appear and can watch, steer or resume later. It costs a
tab and the user's attention, so it is opt-in.

herdr comes in two shapes, and the session uses whichever it runs in:

- **Legacy `herdr`**, a terminal multiplexer: `HERDR_ENV=1`, tabs and panes
  driven by `herdr tab …` and `herdr agent …`.
- **herdr-core**, CLI `hc` (also `herdr-core`), often with the herdr-app
  window: `HC_TERMINAL_ID` holds the session's terminal address. `hc` runs
  the terminals; the app only shows them, in spaces and tabs.

The installed binary is the authority on its syntax: `herdr --skill` or
`hc --skill` (and `herdr-app --skill`) for the full guide, `<command> --help`
for one command. This skill holds the policy, and it wins where the binary's
guide says otherwise.

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
  session started (a legacy tab carries `CLAUDE_HERDR_DELEGATED=1`, an hc
  terminal started from another terminal has a `parent`), sub-agents are
  `Agent` tool calls, even when the brief mentions herdr.
- **`herdr` or `hc`, and the user asked for a visible session**: delegate
  there.
- **`herdr` or `hc`, otherwise**: ask in one line when delegating ("Opus:
  launch it in a visible tab?"), and only for long work the user may want to
  watch or steer, work likely to hit approval prompts, or a session they may
  want to resume. Never for a routine search or a mechanical edit. Without a
  yes, use the `Agent` tool.

The rest of delegating does not change: one agent per worktree, a brief
written like a peer's, and the model (`sonnet` or `opus`) chosen on purpose
and named in the message that launches it.

## Launch

1. **Pick a name** that says what the agent works on and that
   `herdr agent list` or `hc ls` does not already show. `--cwd` below is the
   task's worktree when the main session already created it, `$PWD`
   otherwise.

2. **Start `claude`** in the main session's permission mode: a session in
   another mode holds cross-session messages for its user's approval. Pass no
   `--permission-mode` unless the main session was started with one, and then
   the same.

   - **`herdr`**: open a tab in the current workspace with the marker set and
     the user's focus kept where it is, then start `claude` in its pane
     (`.result.root_pane.pane_id`):

     ```bash
     herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" \
       --label fix-login-timeout --env CLAUDE_HERDR_DELEGATED=1 --no-focus
     herdr agent start fix-login-timeout --kind claude --pane <pane-id> -- --model sonnet
     ```

   - **`hc`**: read the user's current space, start `claude` with `hc run`,
     and wait until it is ready for input, since a brief sent earlier can be
     dropped:

     ```bash
     hc get "$HC_TERMINAL_ID" --json | jq -r '.labels["herdr.space"] // empty'
     hc run --bg --name fix-login-timeout --cwd "$PWD" --outlive-parent --no-notify \
       --label herdr.space=<space-id> -- claude --model sonnet
     hc wait fix-login-timeout
     ```

     The label puts it in a tab of that space in herdr-app; when the first
     command prints nothing, there is no app window to show it in: drop the
     label, and tell the user to open it with `hc attach <name>`. Use
     `hc run`, never `herdr-app do tab.new`: hc records the main session as
     its parent, which the detection above reads. `--outlive-parent` leaves
     its lifetime to the user rather than to the main session's tab, and
     `--no-notify` keeps hc from typing notes into the main session's prompt,
     which the wait and the report below already cover.

3. **Type the brief into it**, as a background command:

   ```bash
   herdr agent prompt fix-login-timeout "<brief>" --wait
   hc send --wait --timeout 3600 fix-login-timeout "<brief>"
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
   Both wait for the turn the brief started, so neither matches the idle
   state the agent has not left yet. An hc `timeout` is a check-in: wait
   again with `hc wait <name>`. An hc `not_started` means read the screen
   with `hc read` before deciding: a resent brief may arrive twice.

## Report and follow-ups

- **The report arrives as a `<cross-session-message>`.** Its `from-name` is
  an auto-generated peer name, unrelated to the herdr or hc name; reply by
  copying its `from` attribute into `SendMessage`'s `to`.
- **Follow-ups go through `SendMessage`** to that address, with
  `notify_when_idle: true`, so an agent that goes idle without answering
  still yields a notice.
- **Fallbacks**, when no report arrives: `herdr agent read <name> --source
  recent-unwrapped` or `hc read <name> --lines 200`, or ask it, through the
  same command as the brief, to write the report to a file and reply with
  the path.
- **A blocked agent is waiting on the user, not on you.** When `agent start`
  returns `agent_not_ready`, or a wait returns `blocked` (a permission prompt,
  a question, the folder-trust dialog of a fresh worktree), tell the user
  which tab is waiting on them. Never answer it with keystrokes: no
  `send-keys`, no `hc keys`, no `hc send --force`. Once the user says it is
  unblocked, wait again with `herdr agent wait <name>` or `hc wait <name>`.

## Leave the layout to the user

- **Never close or end what this flow created**: no tab or pane close, no
  `hc kill` or `hc rm`, whatever `hc --skill` says about cleaning up helpers
  once they report. It is where the user reads what the agent did; they
  close it when they are done with it, or ask you to.
- **Never touch a tab, pane, terminal or agent you did not create.** `hc ls`
  lists the user's other live work too.
- **Never stop or restart the server**: no `herdr server stop`, no
  `hc server stop` or `restart`, which hit every terminal and park the kept
  ones, and never quit herdr-app.
