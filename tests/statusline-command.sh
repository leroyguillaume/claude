#!/usr/bin/env bash
# Runs statusline-command.sh on sample Claude Code payloads, with GNU date and
# with a fake BSD date, and compares the output stripped of its colours.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/statusline-command.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

real_date=$(command -v date)
mkdir "$work/bsd"
cat >"$work/bsd/date" <<EOF
#!/bin/sh
[ "\$1" = -r ] || { echo "date: illegal option -- \${1#-}" >&2; exit 1; }
"$real_date" -d "@\$2" "\$3" 2>/dev/null || exec "$real_date" -r "\$2" "\$3"
EOF
chmod +x "$work/bsd/date"

failures=0

# run_case NAME EXPECTED JSON [VAR=VALUE...]
run_case() {
  local name=$1 expected=$2 json=$3 output
  shift 3
  output=$(printf '%s' "$json" | env TZ=UTC LC_ALL= LANG=C LC_TIME=C "$@" bash "$script" 2>&1 |
    sed $'s/\x1b\\[[0-9;]*m//g')
  if [ "$output" != "$expected" ]; then
    printf 'FAIL %s\n  got:\n%s\n  wanted:\n%s\n' "$name" "$output" "$expected"
    failures=$((failures + 1))
  else
    printf 'ok   %s\n' "$name"
  fi
}

# 1893456000 is Tue 2030-01-01 00:00 UTC.
limits='{"model":{"display_name":"Opus"},"context_window":{"used_percentage":42.7},"rate_limits":{"five_hour":{"used_percentage":61,"resets_at":1893456000},"seven_day":{"used_percentage":85.4,"resets_at":1893456000}}}'
with_limits='Opus ████░░░░░░  42%
5h  ██████░░░░  61% (resets 00:00)
7d  ████████░░  85% (resets Tue 00:00)'

run_case 'shows both rate limits with the host date' "$with_limits" "$limits"
run_case 'shows both rate limits with a BSD-only date' "$with_limits" "$limits" \
  PATH="$work/bsd:$PATH"
run_case 'omits the rate limits Claude Code does not report' 'Opus ████░░░░░░  42%' \
  '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":42.7}}'
run_case 'omits a reset time Claude Code does not report' 'Opus ░░░░░░░░░░   0%
5h  ██░░░░░░░░  20%' \
  '{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":20}}}'
run_case 'falls back to Claude without a model name' 'Claude ░░░░░░░░░░   0%' '{}'

comma_locale=$(locale -a 2>/dev/null | grep -iE '^(fr_FR|de_DE)\.utf-?8$' | head -n 1)
if [ -n "$comma_locale" ]; then
  run_case "reads decimal percentages under $comma_locale" "$with_limits" "$limits" \
    LC_NUMERIC="$comma_locale"
else
  printf 'skip reads decimal percentages under a comma-decimal locale: none installed\n'
fi

colours=$(printf '%s' "$limits" | TZ=UTC LC_ALL=C bash "$script" | grep -o $'\x1b\\[3[123]m' | tr -d '\033[m' | tr '\n' ' ')
if [ "$colours" != '32 33 31 ' ]; then
  printf 'FAIL colours bars green, yellow from 50%%, red from 80%%\n  got: %s\n' "$colours"
  failures=$((failures + 1))
else
  printf 'ok   colours bars green, yellow from 50%%, red from 80%%\n'
fi

[ "$failures" -eq 0 ] || { printf '%s failed\n' "$failures"; exit 1; }
