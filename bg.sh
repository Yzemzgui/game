#!/usr/bin/env bash
# Run a command in the background, logging output and exit code into the work dir.
# Use only if the harness has no native background option.
# usage: bg.sh <workdir> <name> "<command>"
set -u
w=$1; name=$2; cmd=$3
mkdir -p "$w"
rm -f "$w/$name.exit"
nohup bash -c "$cmd; echo \$? > '$w/$name.exit'" > "$w/$name.log" 2>&1 &
echo "started $name (pid $!). log: $w/$name.log  exit code: $w/$name.exit (appears when done)"
