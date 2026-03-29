#!/usr/bin/env bash
# Claude Code status line script
# Reads JSON from stdin, sets terminal title, and outputs a visible status line.

input=$(cat)

# --- Extract fields ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# --- Git branch (cached per directory to avoid slow repeated calls) ---
branch=""
if [ -n "$cwd" ]; then
  cache_dir="${TMPDIR:-/tmp}/claude_statusline_cache"
  mkdir -p "$cache_dir"
  cache_key=$(echo "$cwd" | tr '/' '_')
  cache_file="$cache_dir/${cache_key}.branch"
  cache_ttl=30

  if [ -f "$cache_file" ]; then
    age=$(( $(date +%s) - $(date -r "$cache_file" +%s 2>/dev/null || echo 0) ))
    if [ "$age" -lt "$cache_ttl" ]; then
      branch=$(cat "$cache_file")
    fi
  fi

  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ -n "$branch" ]; then
      echo "$branch" > "$cache_file"
    fi
  fi
fi

# --- Context bar ---
bar=""
bar_width=10
ctx_label="--"
if [ -n "$used_pct" ]; then
  filled=$(echo "$used_pct $bar_width" | awk '{printf "%d", ($1 / 100) * $2 + 0.5}')
  empty=$(( bar_width - filled ))

  # Color: green < 60%, yellow < 80%, red >= 80%
  if awk "BEGIN {exit !($used_pct >= 80)}"; then
    bar_color="\033[0;31m"
  elif awk "BEGIN {exit !($used_pct >= 60)}"; then
    bar_color="\033[0;33m"
  else
    bar_color="\033[0;32m"
  fi
  reset="\033[0m"
  dim="\033[2m"

  bar_filled=$(python3 -c "print('█' * $filled)" 2>/dev/null || printf '%*s' "$filled" '' | tr ' ' '#')
  bar_empty=$(python3 -c "print('░' * $empty)" 2>/dev/null || printf '%*s' "$empty" '' | tr ' ' '-')
  bar="${bar_color}${bar_filled}${dim}${bar_empty}${reset}"
  ctx_label="${bar_color}$(printf '%.0f' "$used_pct")%${reset}"
fi

# --- Terminal title via OSC 0 ---
branch_part=""
[ -n "$branch" ] && branch_part=" | $branch"
ctx_title=""
[ -n "$used_pct" ] && ctx_title=" | ctx:$(printf '%.0f' "$used_pct")%"

printf '\033]0;%s%s%s\007' "$model" "$branch_part" "$ctx_title" > /dev/tty

# --- Visible status line ---
dim="\033[2m"
bold="\033[1m"
cyan="\033[0;36m"
reset="\033[0m"

status="${bold}${cyan}${model}${reset}"

[ -n "$branch" ] && status="${status}  ${dim}${branch}${reset}"

[ -n "$bar" ] && status="${status}  ${bar} ${ctx_label}"

printf '%b\n' "${status}"
