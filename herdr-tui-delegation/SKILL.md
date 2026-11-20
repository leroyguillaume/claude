---
name: herdr-tui-delegation
description: >-
  Herdr TUI commands (`herdr pane`, `herdr workspace`, `herdr tab`,
  `herdr agent`) to find the target repo's workspace, then launch, brief,
  wait on and read a visible `claude` or `opencode` in a tab of its own.
  TRIGGER when: `herdr-delegation` detected `herdr` (`HERDR_ENV=1`, no
  `HC_TERMINAL_ID`) and a visible session is being launched, briefed, waited
  on, read or unblocked.
  SKIP when: `HC_TERMINAL_ID` is set (`herdr-core-delegation`);
  `DELEGATED_AGENT` is set; outside herdr. Load `herdr-delegation`
  alongside.
---

# Delegating through Herdr TUI

Herdr TUI is a terminal multiplexer whose server keeps workspaces, tabs and
panes alive, driven by `herdr tab …` and `herdr agent …`. The policy is
`herdr-delegation`; this skill holds the commands.

The installed binary is the authority on its syntax: `herdr --skill` for the
full guide, `herdr tab <command> --help` and `herdr agent <command> --help`
for one command.

## Loop guard

A tab this flow opens carries `DELEGATED_AGENT=1`, which the detection
in `herdr-delegation` reads: the session in it delegates through its sub-agent
tool, never through another tab.

## Launch

1. **Pick a name** that `herdr agent list` does not already show.

2. **Find the workspace** of a repo other than the main session's, `dir`
   being the directory the agent starts in. The first command lists the
   workspaces with a pane in that repo or its worktrees, the second those
   labelled with the repo's name:

   ```bash
   common() { git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null; }
   key=$(common "$dir"); repo=$(basename "$(dirname "$key")")
   herdr pane list | jq -r '.result.panes[] | [.workspace_id, .cwd] | @tsv' |
     while IFS=$'\t' read -r ws cwd; do [ "$(common "$cwd")" = "$key" ] && echo "$ws"; done | sort -u
   herdr workspace list | jq -r --arg l "$repo" '.result.workspaces[] | select(.label == $l) | .workspace_id'
   ```

   Without `--path-format=absolute`, git prints `.git` relative to each pane,
   which matches every pane at the root of any repo.

3. **Open a tab** in that workspace, or in `$HERDR_WORKSPACE_ID` for the
   main session's repo, labelled with the agent's name, with the marker set
   and the user's focus kept where it is:

   ```bash
   herdr tab create --workspace <workspace-id> --cwd "$dir" \
     --label fix-login-timeout --env DELEGATED_AGENT=1 --no-focus
   ```

   When no workspace holds the repo, create one instead, which comes with
   its tab, then label that tab (`.result.tab.tab_id`) with the agent's name:

   ```bash
   herdr workspace create --cwd "$dir" --label "$repo" \
     --env DELEGATED_AGENT=1 --no-focus
   herdr tab rename <tab-id> fix-login-timeout
   ```

4. **Start the client** in the tab's pane (`.result.root_pane.pane_id`,
   from either command), `--kind claude` or `--kind opencode` as
   `herdr-delegation` picks. Flags after `--` go to the client:

   ```bash
   herdr agent start fix-login-timeout --kind claude --pane <pane-id> -- --model <model>
   ```

5. **Type the brief into it**, as a background command:

   ```bash
   herdr agent prompt fix-login-timeout "<brief>" --wait
   ```

   `--wait` matches the first state observed after submission, so it cannot
   match the idle state the agent has not left yet.

6. **Under OpenCode, read the report** once it returns:

   ```bash
   herdr agent read fix-login-timeout --source recent-unwrapped --lines 200 |
     grep -o 'REPORT: .*' | tail -n 1
   ```

## While it runs

- **Read its screen** with `herdr agent read <name> --source
  recent-unwrapped`.
- **Relay into it**, under OpenCode, as a background command:
  `herdr agent prompt <name> "[relay] <text>" --wait`.
- **Blocked**: `agent start` returns `agent_not_ready`, or a wait returns
  `blocked`. Never answer it with `herdr pane send-keys` or `send-text`.
  Once the user says it is unblocked, wait again with
  `herdr agent wait <name>`.
- **Close the tab this flow created** with `herdr tab close <tab-id>` when
  `herdr-delegation` says to. Never close a pane on its own, never touch a
  tab, pane or agent it did not create, and never `herdr server stop`.
- **Reopen it for a follow-up** with a new tab in the same worktree, as in
  the launch, and `-- --model <model> --continue` to `herdr agent start`,
  or `--session <id>` in place of `--continue` under OpenCode.
