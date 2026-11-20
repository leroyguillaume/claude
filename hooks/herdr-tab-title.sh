#!/bin/sh
# Claude Code Stop hook: names the herdr tab after the terminal title Claude
# Code gives the session, while the tab still has herdr's default numeric label
# or the label this hook gave it for an earlier session, as before a /clear.

input=$(cat)

[ "${HERDR_ENV:-}" = 1 ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

printf '%s' "$input" | jq -e '.agent_id // "" | . == ""' >/dev/null 2>&1 || exit 0
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

pane=$(herdr pane get "$HERDR_PANE_ID" 2>/dev/null) || exit 0
tab_id=$(printf '%s' "$pane" | jq -r '.result.pane.tab_id // empty' 2>/dev/null)
title=$(printf '%s' "$pane" | jq -r '.result.pane.terminal_title_stripped // empty' 2>/dev/null)
[ -n "$tab_id" ] || exit 0
# "Claude Code" is the title a session shows before its first task is named.
case "$title" in '' | 'Claude Code') exit 0 ;; esac

tab=$(herdr tab get "$tab_id" 2>/dev/null) || exit 0
pane_count=$(printf '%s' "$tab" | jq -r '.result.tab.pane_count // empty' 2>/dev/null)
label=$(printf '%s' "$tab" | jq -r '.result.tab.label // empty' 2>/dev/null)
[ "$pane_count" = 1 ] || exit 0
[ "$label" != "$title" ] || exit 0

state_dir=
if [ -n "${XDG_STATE_HOME:-}" ]; then
  state_dir="$XDG_STATE_HOME/claude/herdr-tab-title"
elif [ -n "${HOME:-}" ]; then
  state_dir="$HOME/.local/state/claude/herdr-tab-title"
fi
# Tab ids hold a colon, which Windows forbids in a file name.
state_file=${state_dir:+$state_dir/$(printf '%s' "$tab_id" | tr -c 'A-Za-z0-9._-' '_')}

case "$label" in
  '') exit 0 ;;
  *[!0-9]*)
    [ -n "$session" ] && [ -n "$state_file" ] && [ -f "$state_file" ] || exit 0
    jq -e --arg l "$label" --arg s "$session" \
      '.label == $l and .session_id != $s' "$state_file" >/dev/null 2>&1 || exit 0
    ;;
esac

herdr tab rename "$tab_id" "$title" >/dev/null 2>&1 || exit 0

[ -n "$session" ] && [ -n "$state_file" ] || exit 0
mkdir -p "$state_dir" 2>/dev/null &&
  jq -n --arg l "$title" --arg s "$session" '{label: $l, session_id: $s}' \
    >"$state_file" 2>/dev/null
exit 0
