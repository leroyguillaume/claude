#!/bin/sh
# Claude Code Stop hook: names the herdr tab after the terminal title Claude
# Code gives the session, while the tab still has herdr's default numeric label.

input=$(cat)

[ "${HERDR_ENV:-}" = 1 ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

printf '%s' "$input" | jq -e '.agent_id // "" | . == ""' >/dev/null 2>&1 || exit 0

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
case "$label" in '' | *[!0-9]*) exit 0 ;; esac

herdr tab rename "$tab_id" "$title" >/dev/null 2>&1
exit 0
