#!/usr/bin/env bash
# laguna-bench — real Claude Code smoke test against the CURRENT model server (full tool list, path guard, shim).
# Added 2026-10-16 after F2-1: a trivial one-tool curl test passed, but Claude Code's real tool schemas made Poolside's
# llama.cpp fork answer HTTP 400 on every turn. Run this after every server/config change, before any long run.
# Usage: cc_smoke.sh <arm>   → PASS/FAIL line; details in runs/CC-smoke-<arm>/
set -uo pipefail
ARM="${1:-F}"; B=$HOME/laguna-bench; RID=CC-smoke-$ARM; RD=$B/runs/$RID
rm -rf $RD; $B/bin/drop_db.sh "lb_$(echo $RID | tr -c 'a-zA-Z0-9_\n' _)" >/dev/null 2>&1
$B/bin/prepare_run.sh SMOKE $RID >/dev/null 2>&1 || { echo "FAIL prepare"; exit 1; }
cat > $RD/orders/order-1.md <<'O'
Smoke test. 1) Use Grep to find where `def health` (or any FastAPI health route) is defined under src/ and Read that file.
2) Create tests/unit/test_smoke_cc.py containing one trivial passing pytest test (assert 1 + 1 == 2).
3) Run: python -m pytest -q tests/unit/test_smoke_cc.py   4) Reply with the file you found and the pytest summary line.
O
n0=$(wc -l < $B/logs/shim.jsonl)
PATH_GUARD=1 EXEC_TIMEOUT=600 EXTRA_EXEC_TOOLS=$'Bash(mkdir:*)\nBash(rm:*)' $B/bin/run_executor.sh $ARM $RID $RD/orders/order-1.md > $RD/smoke.json 2>&1
reqs=$(tail -n +$((n0+1)) $B/logs/shim.jsonl); n=$(echo "$reqs" | grep -c '"status"'); bad=$(echo "$reqs" | grep -v '"status": 200' | grep -c '"status"')
passed=$(grep -c "1 passed" $RD/smoke.json); made=$([ -f $RD/repo/tests/unit/test_smoke_cc.py ] && echo 1 || echo 0)
if [ "$bad" = 0 ] && [ "$n" -ge 3 ] && [ "$made" = 1 ] && [ "$passed" -ge 1 ]; then echo "PASS arm=$ARM requests=$n non200=0 file=yes pytest=passed"
else echo "FAIL arm=$ARM requests=$n non200=$bad file=$made pytest_seen=$passed (see $RD/smoke.json, logs/shim.jsonl)"; fi
