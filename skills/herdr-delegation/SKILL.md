---
name: herdr-delegation
description: >-
  Delegating from a Claude Code session inside herdr to a visible `claude` in
  a tab or terminal of its own, one per delegated topic: when to, where it
  opens, the brief, the one-line report, sessions that wait on each other,
  the merge, what never to touch.
  TRIGGER when: the user asks for a visible or herdr sub-agent or session; or,
  inside herdr (`HERDR_ENV=1`, or `HC_TERMINAL_ID` set), a request brings
  several non-trivial topics, or one other than the one the session carries;
  the session pilots; the user says a delegated PR merged; or delegated
  sessions wait on each other's PR, branch or interface.
  SKIP when: the request continues the session's own topic, or is trivial;
  splitting one topic into pieces (`topic-splitting`), unless the user asks
  for them as visible sessions; `CLAUDE_HERDR_DELEGATED` is set or the hc
  terminal has a parent, unless the user asks that session for a tab;
  outside herdr. Load `herdr-tui-delegation` or `herdr-core-delegation`
  alongside.
---

# Delegating through herdr

`CLAUDE.md` decides whether a session carries a topic or pilots. Inside
herdr, every non-trivial topic it delegates goes to a real `claude` session
in a terminal of its own, which the user sees appear and steers directly,
and can resume later; this skill says how. A tab costs the user's attention,
and earns it only where there is a topic of its own to follow.

How one topic splits into pieces, agents and PRs is `topic-splitting`'s. Its
pieces are `Agent` calls, and get tabs of their own only when the user asks
for them.

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

- **`agent`: no tab.** Outside herdr, or in a session another session
  started, sub-agents are `Agent` tool calls, even when the brief mentions
  herdr. Only the user, typing it into that session, can ask it for a tab.
- **`herdr` or `hc`, and the user asked for one or the other** — a visible
  session ("in a tab") or a sub-agent: that wins over the two rules below.
- **`herdr` or `hc`, and a non-trivial topic to delegate** — every one when
  the session pilots, otherwise one other than its own; named by the
  request or surfaced by the look before deciding, such as a dependabot PR
  that fails: one visible session per such topic, with
  `herdr-tui-delegation` or `herdr-core-delegation`, without asking.
- **`herdr` or `hc`, otherwise**: no tab. The session carries its own topic
  itself, with `Agent` calls where they pay, and does a trivial one inline or
  through an `Agent` call.

A session per topic matches how the user follows the work: each topic is
steered, reviewed and followed up on its own, directly in its tab, while the
main session pilots or stays on its own topic. A topic that ends in a PR
keeps its tab as long as the PR (below). Review comments and a red CI land
on the same branch, so the same session picks them up. `git push` and
`gh pr create` ask for approval, which the user answers in the tab. And a
`claude` session can launch `Agent` sub-agents of its own, which an `Agent`
sub-agent cannot, so a topic that turns out long splits from there, under
`topic-splitting`.

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
   then send the main session a one-line report with `SendMessage`, to the
   name `ListAgents` prints as "This session is <name>": the PR's URL, or
   done without a PR, or blocked. No summary: the user reads the details in
   the tab, and the main session's context stays for coordination. A brief
   too long for a command line goes in a file in the scratchpad, and the
   prompt says to read it.

   The brief, and every follow-up, is written in the language the user
   speaks to the main session: they read it in the tab and steer the agent
   from there, and the agent answers in the language it was addressed in.

   The command's exit is the signal that the agent stopped: it returns on
   `blocked` too, and catches an agent that went idle without reporting.

## Report and follow-ups

- **The report arrives as a `<cross-session-message>`.** Its `from-name` is
  an auto-generated peer name, unrelated to the agent's herdr name; reply by
  copying its `from` attribute into `SendMessage`'s `to`.
- **Follow-ups are the user's, in the tab.** The main session relays only
  what the user hands it, through `SendMessage` to that address, with
  `notify_when_idle: true`, so an agent that goes idle without answering
  still yields a notice.
- **A closed tab is reopened, not messaged.** Whether the user closed it or
  it closed at the merge (below), a follow-up handed to the main session
  opens a new tab in the same worktree, running `claude --continue` with the
  same `--model`, which resumes the last conversation held there, and the
  follow-up is typed in as its brief.
- **An agent that stops without its line** is the user's to look at: tell
  them which tab, rather than reading its screen into the main session.
- **A blocked agent is waiting on the user, not on you.** A permission
  prompt, a question, the folder-trust dialog of a fresh worktree: tell the
  user which tab is waiting on them, and never answer it with keystrokes.
  Once the user says it is unblocked, wait again.

## Sessions that wait on each other

Delegated sessions may wait on each other — PRs the pilot stacks, or a
topic's pieces the user asked to see in tabs (`topic-splitting`): a PR to
stack on, a branch to be pushed, an interface to be frozen. **The signal is a message, not a poll
by the session that waits.** A poll lags by its interval, keeps a background
loop running in every waiting tab, and outlives the answer.

- **The main session relays; the sessions never address each other.** The
  names `ListAgents` prints are auto-generated and say nothing about which
  tab is which, while every session already knows the main session's name.
  - Each waiting session's brief has it send the main session a one-line
    `ready`, whose `from` is its address, then wait for the main session's
    signal. Going idle after `ready` is expected, not a missing report: no
    fallback, wait on it again.
  - The producer's brief has it send the main session each event the others
    wait on: the PR's URL and head SHA, the pushed branch, the commit that
    freezes the interface, then every later rebase or force-push, with the
    new SHA.
  - The main session relays each event at once to the sessions waiting on
    it, which start or rebase (`pr-conventions`).
- **A merge is the user's, and so is its signal**: the user tells the main
  session, which relays it the same way (below).
- **Polling is only the fallback**: a sparse check behind the message, or
  the signal itself when the other side is not a session, such as a CI run.
- **A message is a signal, never an approval.** It says something happened;
  it grants nothing the user did not, and a session never asks another to do
  what was blocked or denied in its own. A task's go-ahead is the brief typed
  into its tab, and nothing else.

## When the user says a PR merged

The user tells the main session, not the tab. Once
`gh pr view <branch> --json state` says `MERGED`, in this order:

1. **Close the tab** this flow created for it, before the worktree goes,
   since the agent's cwd lives there.
2. **Remove its worktree and branch**, under `CLAUDE.md`'s post-merge
   cleanup; `git worktree list` finds the worktree from the PR's branch.
3. **Bring the main checkout up to date** (`git pull --ff-only` on the
   default branch), so the user tests what merged, and restart the app if
   the main session runs it.
4. **Relay it** to the sessions stacked on that PR, which rebase
   (above).

## Leave the layout to the user

- **Close what this flow created only once its PR is merged** (above), and
  on no other condition: not when the agent reports, not when it goes idle.
  With no PR, or one still open or closed unmerged, leave it: it is where
  the user reads what the agent did, and they close it, or ask you to. The
  transcript stays on disk, which is what lets a follow-up reopen it.
- **Never touch a tab, pane, terminal or agent you did not create.**
- **Never stop or restart the server**, and never quit herdr-app.
