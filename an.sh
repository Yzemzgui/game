#!/usr/bin/env bash
# Verify comment anchors in one call.
# For each path:line prints: path:line <TAB> in-diff|outside-diff <TAB> exact source text at <head>
# "in-diff" means GitHub accepts a line comment there (inside a PR diff hunk, 3 lines of context).
# usage: anchors.sh <base-ref> <head-sha> <path:line> [<path:line> ...]
set -uo pipefail
base=$1; head=$2; shift 2
for a in "$@"; do
  p=${a%:*}; n=${a##*:}
  text=$(git show "$head:$p" 2>/dev/null | sed -n "${n}p")
  where=$(git diff "$base...$head" -- "$p" | awk -v n="$n" '
    /^@@/ { split($3, r, ","); s = substr(r[1], 2) + 0; c = (r[2] == "" ? 1 : r[2] + 0)
            if (c > 0 && n >= s && n < s + c) f = 1 }
    END { print (f ? "in-diff" : "outside-diff") }')
  printf '%s:%s\t%s\t%s\n' "$p" "$n" "$where" "$text"
done
