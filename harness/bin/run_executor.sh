#!/usr/bin/env bash
# run_executor.sh <arm A|B|X|Q|H> <run_id> <order_file>
# Called by the Opus master (its ONLY way to change code). Launches one headless Claude Code executor
# session in the run's repo and prints a COMPACT JSON summary (full transcript stays in runs/<id>/exec/).
#   Arm A: Claude Sonnet via the normal Claude Code login.
#   Arm B: Laguna S 2.1 via ANTHROPIC_BASE_URL -> local gateway/vLLM (SSH tunnel to the GPU box); every model
#          alias (opus/sonnet/haiku/subagent) is pinned to laguna-s-2.1 so nothing silently reaches Claude.
# Both arms: identical tools/permissions/CLAUDE.md, no web tools, no MCP, no AWS creds, user CLAUDE.md
# and auto-memory excluded, Remote Control enabled (Anand tracks every session on claude.ai/code).
# Follow-up orders in the same run resume the same executor session (keeps its context/thinking).
set -uo pipefail
ARM="$1"; RID="$2"; ORDER="$(realpath -m "$3")"; B=$HOME/laguna-bench; RD=$B/runs/$RID
[ -d "$RD/repo" ] || { echo '{"status":"error","error":"unknown run_id"}'; exit 1; }
[ -f "$ORDER" ] || { echo '{"status":"error","error":"order file not found"}'; exit 1; }
case "$ORDER" in "$RD"/orders/*) ;; *) echo '{"status":"error","error":"order file must be in runs/<id>/orders/"}'; exit 1;; esac
N=$(( $(ls $RD/exec/*.json 2>/dev/null | wc -l) + 1 ))
EXEC_TIMEOUT=${EXEC_TIMEOUT:-2700}
# each call may use the rest of the run's 120-min budget (deadline written by run_master.sh)
[ -s $RD/deadline ] && EXEC_TIMEOUT=$(( $(cat $RD/deadline) - $(date +%s) - 60 )); [ $EXEC_TIMEOUT -lt 60 ] && EXEC_TIMEOUT=60
VENV=$B/wt/lead/.venv
EMPTY=$B/empty; mkdir -p $EMPTY; : > $EMPTY/aws_config; : > $EMPTY/aws_creds

ENVV=(env -i HOME="$HOME" USER="$USER" LANG=C.UTF-8 TERM=dumb
  PATH="$VENV/bin:$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin"
  PYTHONPATH="$RD/repo/src" PYTHONDONTWRITEBYTECODE=1
  AWS_CONFIG_FILE=$EMPTY/aws_config AWS_SHARED_CREDENTIALS_FILE=$EMPTY/aws_creds AWS_EC2_METADATA_DISABLED=true
  CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=laguna-bench
  CLAUDE_CODE_ATTRIBUTION_HEADER=0 DISABLE_AUTOUPDATER=1 BASH_DEFAULT_TIMEOUT_MS=600000 BASH_MAX_TIMEOUT_MS=900000)
# per-run test DB
while IFS= read -r l; do l=${l#export }; ENVV+=("${l//\'/}"); done < $RD/run.env

if [ "$ARM" = A ]; then
  MODEL=sonnet
elif [ "$ARM" = H ]; then
  MODEL=haiku          # Claude Haiku 4.5 via the normal Claude Code login (comparison arm requested by Anand)
elif [[ "$ARM" =~ ^[BXQNDPFGE]$ ]]; then
  # B = Laguna S 2.1, X = Laguna XS 2.1 (33B-A3B, one GPU), Q = Qwen3.6-35B-A3B (GPU1 replica via shim :4001);
  # name must match vLLM --served-model-name
  MODEL=laguna-s-2.1; [ "$ARM" = X ] && MODEL=laguna-xs-2.1; [ "$ARM" = Q ] && MODEL=qwen3.6-35b-a3b; [ "$ARM" = N ] && MODEL=laguna-s-2.1-nvfp4   # N = Laguna S NVFP4, one GPU
  [ "$ARM" = D ] && MODEL=devstral-small-2; [ "$ARM" = P ] && MODEL=nemotron-puzzle-75b   # D = Devstral Small 2 (GPU0), P = Nemotron Puzzle 75B-A9B NVFP4 (GPU1)
  # single-GPU spot box (2026-10-16): F = Laguna S Q5_K_M GGUF, G = Laguna S Q6_K GGUF (llama.cpp), E = Gemma 4 31B (vLLM)
  [ "$ARM" = F ] && MODEL=laguna-s-2.1-q5km; [ "$ARM" = G ] && MODEL=laguna-s-2.1-q6k; [ "$ARM" = E ] && MODEL=gemma-4-31b
  DEFURL=http://127.0.0.1:4000; [[ "$ARM" =~ ^[QNP]$ ]] && DEFURL=http://127.0.0.1:4001
  ENVV+=(ANTHROPIC_BASE_URL="${LAGUNA_BASE_URL:-$DEFURL}" ANTHROPIC_AUTH_TOKEN=dummy-local
    ANTHROPIC_MODEL=$MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL=$MODEL ANTHROPIC_DEFAULT_SONNET_MODEL=$MODEL
    ANTHROPIC_DEFAULT_OPUS_MODEL=$MODEL CLAUDE_CODE_SUBAGENT_MODEL=$MODEL
    API_TIMEOUT_MS=1800000 MAX_THINKING_TOKENS=${LAGUNA_THINKING:-31999})
else echo '{"status":"error","error":"arm must be A, B, X, Q, N, D, P, F, G, E or H"}'; exit 1; fi

SETTINGS='{"autoMemoryEnabled":false,"claudeMdExcludes":["'$HOME'/.claude/CLAUDE.md","**/.claude/CLAUDE.md"]}'
# PATH_GUARD=1: PreToolUse hook confines Bash + file tools to the run's repo (read/write) and /tmp (Anand 2026-10-16)
[ "${PATH_GUARD:-0}" = 1 ] && SETTINGS=$(jq -c --arg cmd "python3 $B/bin/path_guard.py $RD/repo" '. + {hooks:{PreToolUse:[{matcher:"Bash|Read|Edit|Write|MultiEdit|Glob|Grep|NotebookEdit",hooks:[{type:"command",command:$cmd}]}]}}' <<<"$SETTINGS")
ALLOWED=(Read Grep Glob Edit Write "Bash(pytest:*)" "Bash(python -m pytest:*)" "Bash(ruff:*)" "Bash(mypy:*)"
  "Bash(alembic:*)" "Bash(git status:*)" "Bash(git diff:*)" "Bash(ls:*)")
# EXTRA_EXEC_TOOLS: newline-separated extra permission rules (rules may contain spaces, e.g. "Bash(npx tsc:*)")
[ -n "${EXTRA_EXEC_TOOLS:-}" ] && while IFS= read -r t; do [ -n "$t" ] && ALLOWED+=("$t"); done <<< "$EXTRA_EXEC_TOOLS"
RESUME=(); [ -s $RD/exec_session ] && RESUME=(--resume "$(cat $RD/exec_session)")
ADDDIR=(); [ "${PATH_GUARD:-0}" = 1 ] && ADDDIR=(--add-dir /tmp)   # guarded executors may also use /tmp

T0=$(date +%s)
FLAGS=(--model "$MODEL" --setting-sources project --settings "$SETTINGS"
  --strict-mcp-config --mcp-config '{"mcpServers":{}}' --disable-slash-commands
  "${ADDDIR[@]}" --allowedTools "${ALLOWED[@]}" --disallowedTools WebSearch WebFetch Agent Task NotebookEdit EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree)
if [ "${BENCH_HEADLESS:-0}" = 1 ]; then
  cd $RD/repo && timeout --kill-after=30 $EXEC_TIMEOUT "${ENVV[@]}" claude -p "$(cat "$ORDER")" "${RESUME[@]}" \
    --output-format json "${FLAGS[@]}" > $RD/exec/$N.json 2> $RD/exec/$N.stderr
else
  # interactive session in tmux with Remote Control (visible live on claude.ai/code); see rc_session.sh
  export RC_ENV="$(printf '%s\n' "${ENVV[@]:2}" | sed 's/^TERM=dumb$/TERM=xterm-256color/')"
  $B/bin/rc_session.sh "lb-$RID-exec$N" "$RD/repo" "$ORDER" "$RD/exec/$N.json" $EXEC_TIMEOUT "${RESUME[@]}" -- "${FLAGS[@]}" \
    2> $RD/exec/$N.stderr
fi
RC=$?; T1=$(date +%s)
SID=$(jq -r '.session_id // empty' $RD/exec/$N.json 2>/dev/null); [ -n "$SID" ] && echo "$SID" > $RD/exec_session
BASE_SHA=$(cat $RD/baseline_sha)
# intent-to-add new files so the master's `git -C <repo> diff` also shows files the executor created
FILES=$(cd $RD/repo && git add -N . >/dev/null 2>&1; git status --porcelain | awk '{print $2}' | head -50 | jq -R . | jq -sc .)
STATUS=ok; [ $RC -eq 124 ] && STATUS=timeout; [ $RC -ne 0 ] && [ $RC -ne 124 ] && STATUS=error
jq -n --arg st "$STATUS" --argjson rc $RC --argjson n $N --argjson wall $((T1-T0)) --argjson files "$FILES" \
  --slurpfile r <(jq -c . $RD/exec/$N.json 2>/dev/null || echo '{}') \
  --arg err "$(tail -c 600 $RD/exec/$N.stderr 2>/dev/null)" \
  '{status:$st, exit_code:$rc, call:$n, wall_s:$wall, files_changed:$files,
    executor_report:(($r[0].result // "") | .[0:4000]),
    turns:($r[0].num_turns // null), is_error:($r[0].is_error // null),
    tokens:{in:(($r[0].usage.input_tokens // 0)+($r[0].usage.cache_read_input_tokens // 0)+($r[0].usage.cache_creation_input_tokens // 0)), out:($r[0].usage.output_tokens // 0)},
    stderr_tail:(if $st=="ok" then null else $err end),
    next:"Review with: git -C <repo> diff (and git -C <repo> status). Send fixes via a NEW order file + run_executor.sh."}'
