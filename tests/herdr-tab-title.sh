#!/usr/bin/env bash
# Runs hooks/herdr-tab-title.sh against a fake `herdr` that serves canned JSON
# and logs every call, one case per condition the hook checks.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
hook="$root/hooks/herdr-tab-title.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir "$work/bin"
cat >"$work/bin/herdr" <<'EOF'
#!/bin/sh
printf '%s|' "$@" >>"$FAKE_HERDR_LOG"
printf '\n' >>"$FAKE_HERDR_LOG"
[ -z "${FAKE_HERDR_FAIL:-}" ] || { echo '{"error":{"code":"server_not_running"}}'; exit 1; }
case "$1 $2" in
  'pane get') printf '%s\n' "$FAKE_PANE_JSON" ;;
  'tab get') printf '%s\n' "$FAKE_TAB_JSON" ;;
  'tab rename') echo '{"result":{"type":"tab_info"}}' ;;
esac
EOF
chmod +x "$work/bin/herdr"

pane_json() {
  printf '{"result":{"pane":{"pane_id":"w1:p2","tab_id":"%s","terminal_title":"✳ %s","terminal_title_stripped":"%s"}}}' "$1" "$2" "$2"
}

tab_json() {
  printf '{"result":{"tab":{"tab_id":"w1:t3","label":"%s","pane_count":%s}}}' "$1" "$2"
}

failures=0

# run_case NAME EXPECTED_LOG [VAR=VALUE...] -- reads hook input on stdin.
run_case() {
  local name=$1 expected=$2 output status log
  shift 2
  : >"$work/log"
  output=$(env -i \
    PATH="$work/bin:$PATH" \
    FAKE_HERDR_LOG="$work/log" \
    HERDR_ENV=1 HERDR_PANE_ID=w1:p2 HERDR_TAB_ID=w1:t1 \
    FAKE_PANE_JSON="$(pane_json w1:t3 'CI cassée, PRs ouvertes')" \
    FAKE_TAB_JSON="$(tab_json 3 1)" \
    "$@" "$hook" 2>&1)
  status=$?
  log=$(grep rename "$work/log")
  if [ "$status" -ne 0 ] || [ -n "$output" ] || [ "$log" != "$expected" ]; then
    printf 'FAIL %s\n  status: %s\n  output: %s\n  rename: %s\n  wanted: %s\n' \
      "$name" "$status" "$output" "$log" "$expected"
    failures=$((failures + 1))
  else
    printf 'ok   %s\n' "$name"
  fi
}

renamed='tab|rename|w1:t3|CI cassée, PRs ouvertes|'
stop='{"hook_event_name":"Stop","session_id":"s1"}'

run_case 'renames a lone numeric tab after the title' "$renamed" <<<"$stop"
run_case 'resolves the tab from the pane, not HERDR_TAB_ID' "$renamed" \
  HERDR_TAB_ID=w9:t9 <<<"$stop"
run_case 'skips outside herdr' '' HERDR_ENV= <<<"$stop"
run_case 'skips without a pane id' '' HERDR_PANE_ID= <<<"$stop"
run_case 'skips a subagent' '' \
  <<<'{"hook_event_name":"Stop","agent_id":"agent-1"}'
run_case 'skips unparseable input' '' <<<'not json'
run_case 'skips a tab holding several panes' '' \
  FAKE_TAB_JSON="$(tab_json 3 2)" <<<"$stop"
run_case 'keeps a label someone chose' '' \
  FAKE_TAB_JSON="$(tab_json reviewer 1)" <<<"$stop"
run_case 'keeps a label mixing digits and text' '' \
  FAKE_TAB_JSON="$(tab_json 3b 1)" <<<"$stop"
run_case 'skips an empty title' '' \
  FAKE_PANE_JSON="$(pane_json w1:t3 '')" <<<"$stop"
run_case 'skips the title of a session with no task yet' '' \
  FAKE_PANE_JSON="$(pane_json w1:t3 'Claude Code')" <<<"$stop"
run_case 'passes a title starting with a dash as the label' \
  'tab|rename|w1:t3|-n flag|' \
  FAKE_PANE_JSON="$(pane_json w1:t3 '-n flag')" <<<"$stop"
run_case 'stays silent when herdr fails' '' FAKE_HERDR_FAIL=1 <<<"$stop"

mkdir "$work/no-herdr" "$work/no-jq"
ln -s "$(command -v jq)" "$work/no-herdr/jq"
ln -s "$work/bin/herdr" "$work/no-jq/herdr"
for tool in cat grep; do
  ln -s "$(command -v "$tool")" "$work/no-herdr/$tool"
  ln -s "$(command -v "$tool")" "$work/no-jq/$tool"
done
run_case 'stays silent without herdr' '' PATH="$work/no-herdr" <<<"$stop"
run_case 'stays silent without jq' '' PATH="$work/no-jq" <<<"$stop"

[ "$failures" -eq 0 ] || { printf '%s failed\n' "$failures"; exit 1; }
