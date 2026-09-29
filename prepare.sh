#!/usr/bin/env bash
# Fetch base and PR branch, then save everything the review needs into the work dir.
# usage: prepare.sh <base> <branch> <workdir>
set -euo pipefail
base=$1; branch=$2; w=$3
mkdir -p "$w"
git fetch --quiet origin "$base" "$branch"
range="origin/$base...origin/$branch"
git rev-parse "origin/$branch" > "$w/head.txt"
git merge-base "origin/$base" "origin/$branch" > "$w/merge-base.txt"
git diff "$range" > "$w/diff.patch"
git diff --name-status "$range" > "$w/files.txt"
git diff --numstat "$range" > "$w/numstat.txt"
git diff --shortstat "$range" > "$w/stat.txt"
git log --oneline "origin/$base..origin/$branch" > "$w/log.txt"
: > "$w/timing.log"
echo "frame $(date +%s)" >> "$w/timing.log"
echo "head: $(cat "$w/head.txt")"
echo "stat: $(cat "$w/stat.txt")"
echo "commits: $(wc -l < "$w/log.txt")"
echo "--- files"
cat "$w/files.txt"
