#!/usr/bin/env bash
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

level_color() {
  if [ "$1" -ge 80 ]; then
    echo 31
  elif [ "$1" -ge 50 ]; then
    echo 33
  else
    echo 32
  fi
}

progress_bar() {
  local pct=$1 width=10 filled bar=""
  filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled=$width
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = filled; i < width; i++)); do bar+="░"; done
  printf '\033[%sm%s\033[0m %3s%%' "$(level_color "$pct")" "$bar" "$pct"
}

rate_limit_line() {
  local label=$1 key=$2 reset_format=$3 used reset
  used=$(echo "$input" | jq -r ".rate_limits.$key.used_percentage // empty")
  [ -n "$used" ] || return 0
  printf '\n%-3s ' "$label"
  progress_bar "$(printf '%.0f' "$used")"
  reset=$(echo "$input" | jq -r ".rate_limits.$key.resets_at // empty")
  if [ -n "$reset" ]; then
    printf ' (resets %s)' "$(date -r "$reset" "+$reset_format")"
  fi
}

ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx=${ctx%.*}

printf '\033[36m%s\033[0m ' "$model"
progress_bar "${ctx:-0}"
rate_limit_line 5h five_hour '%H:%M'
rate_limit_line 7d seven_day '%a %H:%M'
