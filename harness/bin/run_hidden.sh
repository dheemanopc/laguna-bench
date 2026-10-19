#!/usr/bin/env bash
# run_hidden.sh <task> <worktree> <template> <dbname> [--migrate] [-- extra pytest args]
# Overlays ~/laguna-bench/hidden/<task>/ (repo-relative paths) onto <worktree>, runs those test files
# (FULL=1: run the whole tests/ dir with the overlay in place) on a fresh DB cloned from <template> (optionally `alembic upgrade head` first), then restores the worktree.
set -uo pipefail
task="$1"; wt="$2"; tpl="$3"; db="$4"; shift 4
mig=""; if [ "${1:-}" = "--migrate" ]; then mig="--migrate"; shift; fi
[ "${1:-}" = "--" ] && shift
H=$HOME/laguna-bench/hidden/$task
files=$(cd "$H" && find . -type f -name '*.py' | sed 's|^\./||' | sort)
for f in $files; do mkdir -p "$wt/$(dirname "$f")"; cp "$H/$f" "$wt/$f"; done
targets="$files"; [ "${FULL:-0}" = 1 ] && targets="tests"
$HOME/laguna-bench/bin/run_tests.sh "$wt" "$tpl" "$db" $mig -- -rfE "$@" $targets
rc=$?
for f in $files; do
  if git -C "$wt" cat-file -e "HEAD:$f" 2>/dev/null; then git -C "$wt" checkout -q HEAD -- "$f"; else rm -f "$wt/$f"; fi
done
exit $rc
