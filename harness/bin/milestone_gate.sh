#!/usr/bin/env bash
# milestone_gate.sh <run_id> <label> — full checks at a package milestone / end of run (the scheduler pauses new work
# first, so no task is half-done). Same checks as run_staged.sh gates(): ruff, mypy, alembic heads, full suite vs the
# known-red set (fresh migrated DB), tenant lint (inside the suite), web tsc + build when web changed.
# Writes runs/<id>/gates/<label>.md; exit 0 = no new failures and static checks clean.
set -uo pipefail
RID="$1"; L="$2"; B=$HOME/laguna-bench; RD=$B/runs/$RID; V=$B/wt/lead/.venv/bin; mkdir -p $RD/gates; O=$RD/gates/$L.md
T=$(jq -r .task $RD/run.json)
( cd $RD/repo; fail=0
  echo "## Milestone gate $L (harness-run)"
  r=$($V/ruff check src tests 2>&1 | tail -1); echo "- ruff: $r"; echo "$r" | grep -q "All checks passed" || fail=1
  m=$(flock $RD/.mypy.lock $V/mypy src 2>&1); echo "- mypy: $(echo "$m" | tail -1)"; echo "$m" | tail -1 | grep -q "^Success" || { fail=1; echo "$m" | grep error | head -10 | sed 's/^/    /'; }
  h=$(PYTHONPATH=src $V/alembic heads 2>&1 | grep -c '(head)'); echo "- alembic heads: $h"; [ "$h" = 1 ] || fail=1
  $B/bin/score_task.sh $T $RD/repo $RD/gate_out > /dev/null 2>&1
  echo "- full suite: $(grep '^full suite' $RD/gate_out/score.txt | cut -d: -f2-)"
  n=$(wc -l < $RD/gate_out/new_failures.txt); echo "- NEW failures vs known red: $n"; head -15 $RD/gate_out/new_failures.txt | sed 's/^/    /'; [ "$n" = 0 ] || fail=1
  if [ -n "$(git status --short web | grep -v node_modules)$(git diff --stat $(cat $RD/baseline_sha) -- web | tail -1)" ]; then
    t=$(cd web && flock $RD/.tsc.lock npx tsc --noEmit 2>&1); echo "- web tsc: $(echo "$t" | grep -c 'error TS') errors"; echo "$t" | grep 'error TS' | head -8 | sed 's/^/    /'
    echo "$t" | grep -q 'error TS' && fail=1
    bo=$(cd web && npm run build 2>&1); echo "- web build: $(echo "$bo" | grep -E 'Compiled|Failed|rror' | head -3 | tr '\n' ' ')"; echo "$bo" | grep -q -E 'Failed to compile|Build error|Type error' && fail=1
  else echo "- web: no changes"; fi
  [ $fail = 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"; exit $fail ) > $O 2>&1
rc=$?; cat $O; exit $rc
