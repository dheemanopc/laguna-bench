#!/usr/bin/env bash
# laguna-bench — F2 pass 1 (Anand 2026-10-16): Opus (owner Q&A + final acceptance, read-heavy/output-capped) + ONE Laguna
# engineer, minimal hand-holding: abstract packet, engineer writes its own design doc first, no work orders, no code review.
# Wider permissions per Anand: free file ops + scripts + web gates INSIDE the run repo or /tmp (path_guard.py enforces).
# Usage: run_f2.sh <run_id> [arm=F]
set -uo pipefail
RID="${1:-F2-1}"; ARM="${2:-F}"; B=$HOME/laguna-bench
export RUN_CAP=${RUN_CAP:-18000} DESIGN_DOC=docs/design/team-workflows.md Q_ROUNDS=3 ACCEPT=1 PATH_GUARD=1
export EXTRA_EXEC_TOOLS=$(printf '%s\n' "Bash(mkdir:*)" "Bash(rm:*)" "Bash(mv:*)" "Bash(cp:*)" "Bash(touch:*)" "Bash(cat:*)" \
  "Bash(head:*)" "Bash(tail:*)" "Bash(wc:*)" "Bash(find:*)" "Bash(grep:*)" "Bash(sed:*)" "Bash(diff:*)" "Bash(sort:*)" "Bash(echo:*)" \
  "Bash(python:*)" "Bash(python3:*)" "Bash(git:*)" "Bash(cd:*)" \
  "Bash(npm run lint:*)" "Bash(npm run build:*)" "Bash(npx tsc:*)" "Bash(npx next:*)" "Bash(npx eslint:*)")
exec $B/bin/run_solo.sh F2 "$RID" "$ARM"
