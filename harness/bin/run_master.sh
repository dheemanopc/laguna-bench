#!/usr/bin/env bash
# run_master.sh <task Tn> <run_id> <arm A|B>
# Runs one benchmark run: a headless Opus 5.5 master that plans from the task packet, delegates ALL code
# changes to the executor through run_executor.sh, reviews the returned diff, and sends fixes back.
# The master cannot edit code (Edit/NotebookEdit disallowed; Write is scoped to its orders/ folder only),
# has no web tools, no MCP, no AWS credentials. 120-minute wall-clock cap. Remote Control enabled.
# Identical for both arms except the arm letter passed to run_executor.sh (the master is not told the model).
set -uo pipefail
T="$1"; RID="$2"; ARM="$3"; B=$HOME/laguna-bench; RD=$B/runs/$RID
[ -d $RD/repo ] || { echo "run dir missing; run prepare_run.sh first"; exit 1; }
RUN_CAP=${RUN_CAP:-7200}
EMPTY=$B/empty; mkdir -p $EMPTY; : > $EMPTY/aws_config; : > $EMPTY/aws_creds
PACKET="$(cat $B/tasks/$T/packet.md)"
read -r -d '' PROTOCOL <<EOF
You are the lead engineer (planner/reviewer) for one task on this repository. You do NOT write code yourself.
An executor engineer makes every code change. Your job: understand the task and the codebase, plan, delegate,
review the executor's diff critically, and send it back with precise fixes until the task is done well.

How to delegate (the only way code changes):
1. Write a work order (markdown) with the Write tool to a NEW file:
   $RD/orders/order-<n>.md   (n = 1, 2, 3 ...; never overwrite an earlier order)
   The executor sees only the repository (with CLAUDE.md and CONVENTIONS.md) and your work order — not this task
   text — so make each order self-contained: goal, relevant files/patterns, acceptance criteria, which tests to run.
2. Run:  $B/bin/run_executor.sh $ARM $RID $RD/orders/order-<n>.md
   (use a Bash timeout of 7500000 ms; executor calls can take a long time — wait for them in the foreground). It returns a JSON summary (status, files changed, executor report, tokens).
   Follow-up orders continue the same executor session.
3. Review with:  git -C $RD/repo diff   and   git -C $RD/repo status
   Check correctness, edge cases, adherence to CONVENTIONS.md, tests, and that no tests were weakened.
4. Repeat 1-3 until satisfied. Be efficient: aim for few, high-quality round-trips.

Rules: do not try to edit files yourself; you cannot run tests or other commands yourself (only Read/Grep/Glob, writing order files, run_executor.sh and git diff/status) — ask the executor to run tests and report exact results; do not use web access; stay within this repository.
When finished, reply with a final report: summary of the solution, number of executor round-trips, remaining
concerns, and your confidence that the task's acceptance criteria are met.

=== TASK PACKET ===
$PACKET
EOF
SETTINGS='{"autoMemoryEnabled":false,"claudeMdExcludes":["'$HOME'/.claude/CLAUDE.md","**/.claude/CLAUDE.md"]}'
echo "$(date -u +%FT%TZ) start" > $RD/master.started
T0=$(date +%s); echo $((T0+RUN_CAP)) > $RD/deadline   # run_executor.sh caps each call at the remaining run budget
printf '%s' "$PROTOCOL" > $RD/master.prompt.md
MENV=(HOME="$HOME" USER="$USER" LANG=C.UTF-8 TERM=xterm-256color
  PATH="$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin"
  AWS_CONFIG_FILE=$EMPTY/aws_config AWS_SHARED_CREDENTIALS_FILE=$EMPTY/aws_creds AWS_EC2_METADATA_DISABLED=true
  CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=laguna-bench DISABLE_AUTOUPDATER=1
  BASH_DEFAULT_TIMEOUT_MS=7500000 BASH_MAX_TIMEOUT_MS=7500000 EXTRA_EXEC_TOOLS="${EXTRA_EXEC_TOOLS:-}"
  LAGUNA_BASE_URL="${LAGUNA_BASE_URL:-}" BENCH_HEADLESS="${BENCH_HEADLESS:-0}")
MFLAGS=(--model opus --setting-sources project --settings "$SETTINGS"
  --strict-mcp-config --mcp-config '{"mcpServers":{}}' --disable-slash-commands
  --add-dir "$RD/orders"
  --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" "Bash($B/bin/run_executor.sh:*)"
     "Bash(git -C $RD/repo diff:*)" "Bash(git -C $RD/repo status:*)"
  --disallowedTools "Edit(/$RD/repo/**)" WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree)
if [ "${BENCH_HEADLESS:-0}" = 1 ]; then
  cd $RD/repo && timeout --kill-after=60 $RUN_CAP env -i "${MENV[@]}" claude -p "$PROTOCOL" --output-format json "${MFLAGS[@]}" \
    > $RD/master.json 2> $RD/master.stderr
else
  # interactive + Remote Control (watch live on claude.ai/code as "lb-<run>-master")
  export RC_ENV="$(printf '%s\n' "${MENV[@]}")"
  $B/bin/rc_session.sh "lb-$RID-master" "$RD/repo" "$RD/master.prompt.md" "$RD/master.json" $RUN_CAP -- "${MFLAGS[@]}" 2> $RD/master.stderr
fi
RC=$?; T1=$(date +%s)
# reap this run's executor sessions: a capped master must not leave an orphan executor running (found 2026-10-16)
for s in $(tmux ls -F '#S' 2>/dev/null | grep "^rc-lb-$RID-"); do tmux kill-session -t "$s"; done
for p in $(pgrep -f "bin/(run_executor|rc_session)\.sh .*[ -]$RID( |-)"); do kill "$p" 2>/dev/null; done
jq -n --arg rid "$RID" --arg t "$T" --arg arm "$ARM" --argjson rc $RC --argjson wall $((T1-T0)) \
  --argjson calls "$(ls $RD/exec/*.json 2>/dev/null | wc -l)" \
  '{run_id:$rid, task:$t, arm:$arm, master_exit:$rc, timed_out:($rc==124), wall_s:$wall, executor_calls:$calls}' > $RD/master.summary.json
cat $RD/master.summary.json
