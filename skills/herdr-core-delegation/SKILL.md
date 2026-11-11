---
name: herdr-core-delegation
description: >-
  herdr-core commands (`hc run`, `hc send`, `hc wait`) to launch, brief, wait
  on and read a visible `claude` in a terminal of its own, shown as a tab by
  herdr-app.
  TRIGGER when: `herdr-delegation` detected `hc` (`HC_TERMINAL_ID` set, the
  terminal has no parent) and a visible session is being launched, briefed,
  waited on, read or unblocked.
  SKIP when: `HC_TERMINAL_ID` is unset (`herdr-tui-delegation`); the hc
  terminal has a parent; outside herdr. Load `herdr-delegation` alongside.
---

# Delegating through herdr-core

herdr-core, CLI `hc` (also `herdr-core`), runs terminals that outlive whoever
views them; herdr-app, when it is open, only shows them, in spaces and tabs.
`HC_TERMINAL_ID` holds the session's terminal address. The policy is
`herdr-delegation`; this skill holds the commands.

The installed binary is the authority on its syntax: `hc --skill` (and
`herdr-app --skill`) for the full guide, `hc <command> --help` for one
command.

## Loop guard

hc records the terminal a terminal was started from as its `parent`, which
the detection in `herdr-delegation` reads: a session whose terminal has one
delegates through the `Agent` tool. Herdr TUI's environment marker does not
work here: `hc run` has no `--env`, and wrapping `claude` in `env` makes hc
see the agent as `env`.

## Launch

1. **Pick a name** that `hc ls` does not already show.

2. **Start `claude`** with `hc run`, in the directory and space
   `herdr-delegation` picks, and wait until it is ready for input, since a
   brief sent earlier can be dropped. Flags after `claude` go to it:

   ```bash
   hc get "$HC_TERMINAL_ID" --json | jq -r '.labels["herdr.space"] // empty'
   hc run --bg --name fix-login-timeout --cwd <dir> --outlive-parent --no-notify \
     --label herdr.space=<space-id> -- claude --model <model>
   hc wait fix-login-timeout
   ```

   The first command prints the current space, the one for the main
   session's repo. For another repo, find its space from what `hc --skill`
   documents; when it gives no way to find or create one, use the current
   space and tell the user. The label puts it in a tab of that space in
   herdr-app; when the first command prints nothing, there is no app window
   to show it in: drop the label, and tell the user to open it with
   `hc attach <name>`. Use `hc run`,
   never `herdr-app do tab.new`: hc records the main session as its parent,
   which the loop guard reads. `--outlive-parent` leaves its lifetime to the
   user rather than to the main session's tab, and `--no-notify` keeps hc
   from typing notes into the main session's prompt, which the wait and the
   report already cover.

3. **Type the brief into it**, as a background command:

   ```bash
   hc send --wait --timeout 3600 fix-login-timeout "<brief>"
   ```

   It waits for the turn the brief started, so it cannot match the idle state
   the agent has not left yet. A `timeout` is a check-in: wait again with
   `hc wait <name>`. A `not_started` means read the screen before deciding: a
   resent brief may arrive twice.

## While it runs

- **Read its screen** with `hc read <name> --lines 200`.
- **Blocked**: a wait returns `blocked`. Never answer it with `hc keys` or
  `hc send --force`. Once the user says it is unblocked, wait again with
  `hc wait <name>`.
- **End the terminal this flow created** with `hc kill <name>` then
  `hc rm <name>` when `herdr-delegation` says to, whatever `hc --skill` says
  about cleaning up helpers once they report.
- **Reopen it for a follow-up** with `hc run` in the same worktree, as in the
  launch, ending in `-- claude --model <model> --continue`.
- **Never touch a terminal it did not create**: `hc ls` lists the user's
  other live work too.
- **Never** `hc server stop` or `restart`, which hit every terminal and park
  the kept ones.
