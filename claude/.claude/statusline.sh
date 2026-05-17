#!/usr/bin/env bash
# Claude Code status line: [Model effort] cwd branch | ctx N% | 5h N%
# Colors: green ≤50%, yellow 50-80%, red >80% for ctx and 5h usage.

input=$(cat)

model=$(echo "$input"  | jq -r '.model.display_name // "?"' | sed 's/ (.*context)//')
effort=$(echo "$input" | jq -r '.effort.level // ""')
cwd_raw=$(echo "$input" | jq -r '.cwd // "."')
cwd=${cwd_raw/#$HOME/\~}
ctx=$(echo "$input"    | jq -r '(.context_window.used_percentage // 0) | floor')
rate5h=$(echo "$input" | jq -r '(.rate_limits.five_hour.used_percentage // 0) | floor')
branch=$(git -C "$cwd_raw" branch --show-current 2>/dev/null)

color() {
  if [ "$1" -gt 80 ]; then echo "31"
  elif [ "$1" -gt 50 ]; then echo "33"
  else echo "32"
  fi
}

ctx_c=$(color "$ctx")
rate_c=$(color "$rate5h")

header="[$model${effort:+ $effort}]"
branch_seg="${branch:+ $branch}"

printf '%s %s%s | \033[%smctx %s%%\033[0m | \033[%sm5h %s%%\033[0m' \
  "$header" "$cwd" "$branch_seg" "$ctx_c" "$ctx" "$rate_c" "$rate5h"
