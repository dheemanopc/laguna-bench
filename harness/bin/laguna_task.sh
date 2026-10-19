#!/usr/bin/env bash
# laguna_task.sh <run_id> <key> <prompt_file> [rw|ro]
# F2-4 harness (Anand 2026-10-17): ONE Laguna task = ONE fresh headless Claude Code session (never resumed), so no
# session ever reaches auto-compaction. Several run in parallel in the same working tree (the scheduler keeps their
# files disjoint). Per session:
#   - its own test DB (cloned from the migrated template), so parallel test runs never collide
#   - a context watchdog: the transcript's live context (input + cache read + cache write of the latest turn) is polled;
#     above CTX_LIMIT (default 100k) the session is stopped and the scheduler hands the task to a continuation session
#   - the path guard (repo + /tmp; GET-only web on a docs allow-list), no MCP, no subagents, user CLAUDE.md excluded
#   - ro = review mode (read + git diff only)
# LAGUNA_GUARDS (2026-10-19): when set to 1, enables:
#   - suppress_guard.py: PreToolUse hook rejecting # noqa, type: ignore, pytest suppressions (except asyncpg import)
#   - finish_guard.py: Stop hook ensuring planned test files (LAGUNA_TASK_TESTS) exist before finishing
# LAGUNA_TASK_TESTS (2026-10-19): comma-separated list of planned test file paths; passed to finish_guard hook
# Writes runs/<id>/t/<key>.json (claude result), <key>.stderr, <key>.meta.json; prints the meta JSON.
set -uo pipefail
RID="$1"; KEY="$2"; PROMPT="$3"; MODE="${4:-rw}"; B=$HOME/laguna-bench; RD=$B/runs/$RID; T=$RD/t; mkdir -p $T
MODEL=${LAGUNA_MODEL:-laguna-s-2.1}; CTX_LIMIT=${CTX_LIMIT:-0}; THINK=${LAGUNA_THINKING:-8000}; case "$KEY" in goal-*|plan-*) CTX_LIMIT=${PLAN_CTX_LIMIT:-200000}; THINK=${LAGUNA_PLAN_THINKING:-31999};; esac; TMO=${TASK_TIMEOUT:-3600}
# hosted backend (2026-10-17, OpenRouter): LAGUNA_BASE_URL=https://openrouter.ai/api LAGUNA_KEY_FILE=<file> LAGUNA_MODEL=poolside/laguna-s-2.1
# the key is read from the file at run time, never logged; local shim default = dummy token
TOKEN=dummy-local; [ -n "${LAGUNA_KEY_FILE:-}" ] && TOKEN=$(cat "$LAGUNA_KEY_FILE")
VENV=$B/wt/lead/.venv; EMPTY=$B/empty; mkdir -p $EMPTY; : > $EMPTY/aws_config; : > $EMPTY/aws_creds
SID=$(python3 -c 'import uuid;print(uuid.uuid4())')
DB="lb_$(echo "${RID}_$KEY" | tr -c 'a-zA-Z0-9_\n' _ | tr 'A-Z' 'a-z')"
DSN=$($B/bin/fresh_db_tpl.sh bench_tpl "$DB" 2>/dev/null)
ENVV=(env -i HOME="$HOME" USER="$USER" LANG=C.UTF-8 TERM=dumb
  PATH="$VENV/bin:$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin"
  PYTHONPATH="$RD/repo/src" PYTHONDONTWRITEBYTECODE=1
  AWS_CONFIG_FILE=$EMPTY/aws_config AWS_SHARED_CREDENTIALS_FILE=$EMPTY/aws_creds AWS_EC2_METADATA_DISABLED=true
  CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_CODE_ATTRIBUTION_HEADER=0 DISABLE_AUTOUPDATER=1
  BASH_DEFAULT_TIMEOUT_MS=600000 BASH_MAX_TIMEOUT_MS=900000
  ANTHROPIC_BASE_URL="${LAGUNA_BASE_URL:-http://127.0.0.1:4000}" ANTHROPIC_AUTH_TOKEN="$TOKEN" ANTHROPIC_API_KEY=
  ANTHROPIC_MODEL=$MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL=$MODEL ANTHROPIC_DEFAULT_SONNET_MODEL=$MODEL
  ANTHROPIC_DEFAULT_OPUS_MODEL=$MODEL CLAUDE_CODE_SUBAGENT_MODEL=$MODEL API_TIMEOUT_MS=1800000
  MAX_THINKING_TOKENS=$THINK)
# larger context (2026-10-18, BF16 on 4 GPUs): LAGUNA_CTX_WINDOW=N makes Claude Code treat the model as 1M-window ([1m] suffix,
# stripped before the request) and auto-compact at N instead of ~170k. Keep N below the server max-model-len (vLLM 262144).
[ -z "${LAGUNA_CTX_WINDOW+x}" ] && case "$RID" in F2-5*) LAGUNA_CTX_WINDOW=245000;; esac   # full build only; BF-x replays stay comparable with fp4
MODEL_ARG=$MODEL; if [ -n "${LAGUNA_CTX_WINDOW:-}" ]; then MODEL_ARG="$MODEL[1m]"; ENVV+=(CLAUDE_CODE_AUTO_COMPACT_WINDOW=$LAGUNA_CTX_WINDOW)
  [ "$CTX_LIMIT" = 200000 ] && CTX_LIMIT=$LAGUNA_CTX_WINDOW; fi
# Sonnet engineer baseline (2026-10-19): LAGUNA_BACKEND=anthropic LAGUNA_MODEL=claude-sonnet-5-5 runs the SAME harness on the
# user's own Claude login (HOME credentials): no base URL/token/model/thinking overrides, Claude Code's own context handling.
# Cost = the session's total_cost_usd in t/<key>.json (API-equivalent).
if [ "${LAGUNA_BACKEND:-}" = anthropic ]; then MODEL_ARG=$MODEL; E2=()
  for e in "${ENVV[@]}"; do case "$e" in ANTHROPIC_*|MAX_THINKING_TOKENS=*|CLAUDE_CODE_SUBAGENT_MODEL=*|CLAUDE_CODE_AUTO_COMPACT_WINDOW=*|API_TIMEOUT_MS=*) ;; *) E2+=("$e");; esac; done
  ENVV=("${E2[@]}"); fi
while IFS= read -r l; do l=${l#export }; [ -n "$l" ] && ENVV+=("${l//\'/}"); done <<< "$DSN"
# Add test file list and guards flag if present
[ -n "${LAGUNA_TASK_TESTS:-}" ] && ENVV+=(LAGUNA_TASK_TESTS="$LAGUNA_TASK_TESTS")
[ "${LAGUNA_GUARDS:-}" = 1 ] && ENVV+=(LAGUNA_GUARDS=1)
# Build SETTINGS JSON with conditional guards (2026-10-19)
if [ "${LAGUNA_GUARDS:-}" = 1 ]; then
  SETTINGS=$(jq -nc --arg cmd "python3 $B/bin/path_guard.py $RD/repo" --arg suppress "python3 $B/bin/suppress_guard.py" --arg finish "python3 $B/bin/finish_guard.py" --arg home "$HOME" \
    '{autoMemoryEnabled:false, claudeMdExcludes:[($home+"/.claude/CLAUDE.md"),"**/.claude/CLAUDE.md"],
      hooks:{PreToolUse:[{matcher:"Bash|Read|Edit|Write|MultiEdit|Glob|Grep|NotebookEdit|WebFetch",hooks:[{type:"command",command:$cmd}]},{matcher:"Bash|Edit|Write|MultiEdit",hooks:[{type:"command",command:$suppress}]}],Stop:[{hooks:[{type:"command",command:$finish}]}]}}')
else
  SETTINGS=$(jq -nc --arg cmd "python3 $B/bin/path_guard.py $RD/repo" --arg home "$HOME" \
    '{autoMemoryEnabled:false, claudeMdExcludes:[($home+"/.claude/CLAUDE.md"),"**/.claude/CLAUDE.md"],
      hooks:{PreToolUse:[{matcher:"Bash|Read|Edit|Write|MultiEdit|Glob|Grep|NotebookEdit|WebFetch",hooks:[{type:"command",command:$cmd}]}]}}')
fi
TURNS=()
if [ "$MODE" = ro ]; then
  # F2-4: a read-only review sprawled to 74 tool calls / 32 min / 156k for a 2-file task -> hard cap turns + context
  TURNS=(--max-turns ${REVIEW_MAX_TURNS:-12}); CTX_LIMIT=${REVIEW_CTX_LIMIT:-60000}
  ALLOWED=(Read Grep Glob "Bash(git diff:*)" "Bash(git status:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(ls:*)")
  DENY=(Edit Write MultiEdit NotebookEdit WebSearch WebFetch Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree)
else
  ALLOWED=(Read Grep Glob Edit Write MultiEdit WebFetch "Bash(pytest:*)" "Bash(python -m pytest:*)" "Bash(ruff:*)" "Bash(mypy:*)"
    "Bash(alembic:*)" "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(ls:*)"
    "Bash(mkdir:*)" "Bash(rm:*)" "Bash(mv:*)" "Bash(cp:*)" "Bash(touch:*)" "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)"
    "Bash(wc:*)" "Bash(find:*)" "Bash(grep:*)" "Bash(sed:*)" "Bash(diff:*)" "Bash(sort:*)" "Bash(echo:*)" "Bash(python:*)"
    "Bash(python3:*)" "Bash(cd:*)" "Bash(curl:*)" "Bash(npm run lint:*)" "Bash(npm run build:*)" "Bash(npx tsc:*)"
    "Bash(npx next:*)" "Bash(npx eslint:*)" "Bash(npx playwright:*)")
  DENY=(WebSearch Agent Task NotebookEdit EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree "Bash(git commit:*)"
    "Bash(git reset:*)" "Bash(git checkout:*)" "Bash(git stash:*)" "Bash(git clean:*)" "Bash(git restore:*)")
fi
TX="$HOME/.claude/projects/$(echo "$RD/repo" | sed 's/[^a-zA-Z0-9]/-/g')/$SID.jsonl"
T0=$(date +%s)
cd $RD/repo
timeout --kill-after=30 $TMO "${ENVV[@]}" claude -p "$(cat "$PROMPT")" --session-id "$SID" --output-format json \
  --model "$MODEL_ARG" --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --disable-slash-commands "${TURNS[@]}" --add-dir /tmp --allowedTools "${ALLOWED[@]}" --disallowedTools "${DENY[@]}" \
  > $T/$KEY.json 2> $T/$KEY.stderr &
CPID=$!
CTXMAX=0; KILLED=""
while kill -0 $CPID 2>/dev/null; do
  sleep 10
  if [ -f "$TX" ]; then
    c=$(jq -c 'select(.message.usage) | .message.usage | (.input_tokens//0)+(.cache_read_input_tokens//0)+(.cache_creation_input_tokens//0)' "$TX" 2>/dev/null | tail -1)
    [ -n "$c" ] && [ "$c" -gt "$CTXMAX" ] && CTXMAX=$c
    if [ "$CTX_LIMIT" -gt 0 ] && [ -n "$c" ] && [ "$c" -gt "$CTX_LIMIT" ]; then KILLED=ctx; kill $CPID 2>/dev/null; break; fi
  fi
done
wait $CPID 2>/dev/null; RC=$?; T1=$(date +%s)
COMPACTS=$(grep -c -E '"compact_boundary"|"isCompactSummary":true' "$TX" 2>/dev/null); COMPACTS=${COMPACTS:-0}
$B/bin/drop_db.sh "$DB" >/dev/null 2>&1
STATUS=ok; [ -n "$KILLED" ] && STATUS=ctx_limit; [ -z "$KILLED" ] && [ $RC -eq 124 ] && STATUS=timeout
[ -z "$KILLED" ] && [ $RC -ne 0 ] && [ $RC -ne 124 ] && STATUS=error
jq -n --arg st "$STATUS" --argjson rc $RC --arg sid "$SID" --argjson wall $((T1-T0)) --argjson ctx $CTXMAX --arg key "$KEY" --argjson compacts $COMPACTS \
  --arg res "$(jq -r '.result // ""' $T/$KEY.json 2>/dev/null)" --arg err "$(tail -c 400 $T/$KEY.stderr 2>/dev/null)" \
  '{key:$key, status:$st, compactions:$compacts, rc:$rc, session_id:$sid, wall_s:$wall, ctx_max:$ctx, result:$res, stderr_tail:$err}' | tee $T/$KEY.meta.json
