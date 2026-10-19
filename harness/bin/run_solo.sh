#!/usr/bin/env bash
# run_solo.sh <task Tn> <run_id> [arm=B]
# "Solo" arm: the executor model (Laguna by default) receives the task packet AS-IS — no Opus exploration,
# no work orders, no Opus code review. It plans and implements end to end with the normal executor tools and
# permissions. If requirements are ambiguous or conflict with existing code/docs it writes QUESTIONS.md and
# stops; Opus then answers as the BUSINESS OWNER only (frontier owns business intent — Anand's role split),
# and the same executor session resumes with the answers (max 2 question rounds). 120-min run cap.
# All sessions interactive with Remote Control (rc_session.sh). Scored like any other run by run_queue/score_task.
# Feature mode (env, defaults keep the T-task behaviour): DESIGN_DOC=<repo path> -> engineer writes its own design doc first
# (nobody approves it, it continues straight on); Q_ROUNDS (default 2); RUN_CAP (s, default 7200);
# ACCEPT=1 -> final Opus acceptance (read-heavy, output-capped: Anand wants Opus to spend input tokens, not output tokens).
# Opus owner answers are output-capped too (one decision + one-line reason each).
set -uo pipefail
T="$1"; RID="$2"; ARM="${3:-B}"; B=$HOME/laguna-bench; RD=$B/runs/$RID
[ -d $RD/repo ] || $B/bin/prepare_run.sh $T $RID >/dev/null || exit 1
RUN_CAP=${RUN_CAP:-7200}; T0=$(date +%s); echo $((T0+RUN_CAP)) > $RD/deadline
echo "$(date -u +%FT%TZ) start (solo, arm $ARM)" > $RD/master.started
PACKET="$(cat $B/tasks/$T/packet.md)"
cat > $RD/orders/order-1.md <<EOF
You are the engineer responsible for this task end to end: understand the requirements and the codebase,
design the solution, implement it, write tests, and verify it. Nobody will review your code before scoring.

Business questions: the requirements below come from the product owner. If, after reading the relevant code and
docs, something in the requirements is genuinely ambiguous or conflicts with existing behaviour or the design docs,
write your questions (numbered, each with the options you see and your recommended choice) to QUESTIONS.md in the
repository root and END YOUR TURN without implementing; the answers will be sent to you. Ask only if the answer
would change what you build. Otherwise proceed and record any assumptions in your final report.

When finished, reply with a short report: what you changed, how you verified it (commands + results), assumptions.
${DESIGN_DOC:+
Before writing code, write your own design for this feature to $DESIGN_DOC (data model, rules, interfaces, UI, migration
of existing data, test plan, open risks). Nobody will approve it: continue straight into implementation and keep the
doc in sync if you change your mind.}

=== TASK ===
$PACKET
EOF
SETTINGS='{"autoMemoryEnabled":false,"claudeMdExcludes":["'$HOME'/.claude/CLAUDE.md","**/.claude/CLAUDE.md"]}'
answer_questions() {   # $1 = question round number
  local qn=$1
  cp $RD/repo/QUESTIONS.md $RD/orders/questions-$qn.md
  cat > $RD/orders/answer-prompt-$qn.md <<EOF
You are the product owner for the task below (business intent only). An engineer working on it sent you questions
(in $RD/orders/questions-$qn.md). You may read the repository at $RD/repo (code + docs) to answer accurately.
Answer each question with ONE decision and a ONE-line reason (no more). Read as much as you need; write as little as possible. Do NOT write code or give implementation
instructions beyond what the business decision requires. Write your answers with the Write tool to
$RD/orders/answers-$qn.md and then end your turn.

=== TASK (as given to the engineer) ===
$PACKET
EOF
  export RC_ENV="$(printf '%s\n' HOME=$HOME USER=$USER LANG=C.UTF-8 TERM=xterm-256color "PATH=$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin" CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 DISABLE_AUTOUPDATER=1)"
  $B/bin/rc_session.sh "lb-$RID-owner$qn" "$RD/repo" "$RD/orders/answer-prompt-$qn.md" "$RD/owner-$qn.json" 1800 -- \
    --model opus --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
    --disable-slash-commands --add-dir "$RD/orders" --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" \
    --disallowedTools "Edit(/$RD/repo/**)" WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree
  { echo "Answers from the product owner to your questions:"; echo; cat $RD/orders/answers-$qn.md 2>/dev/null || echo "(no answers received — use your recommended choices)";
    echo; echo "Continue: implement, test, verify, and report as instructed. Remove QUESTIONS.md when done."; } > $RD/orders/order-$((qn+1)).md
  rm -f $RD/repo/QUESTIONS.md
}
$B/bin/run_executor.sh $ARM $RID $RD/orders/order-1.md > $RD/exec-1.summary.json
for qn in $(seq 1 ${Q_ROUNDS:-2}); do
  [ -f $RD/repo/QUESTIONS.md ] || break
  [ $(( $(date +%s) - T0 )) -ge $((RUN_CAP-300)) ] && break
  echo "$(date -u +%FT%TZ) question round $qn" >> $RD/master.started
  answer_questions $qn
  $B/bin/run_executor.sh $ARM $RID $RD/orders/order-$((qn+1)).md > $RD/exec-$((qn+1)).summary.json
done
if [ "${ACCEPT:-0}" = 1 ]; then   # ---- final Opus acceptance: read-heavy, output-capped ----
  (cd $RD/repo && git add -A >/dev/null 2>&1 && git diff --cached --stat $(cat $RD/baseline_sha) | tail -60 > $RD/orders/delivered.stat; git reset -q)
  cat > $RD/orders/accept.prompt.md <<ACC
You are the product owner doing the final ACCEPTANCE of this feature. The original request is below. The engineer worked
alone. Read whatever you need: the repository at $RD/repo (its design doc ${DESIGN_DOC:-if any}, code, migrations, tests,
web UI), the change summary $RD/orders/delivered.stat, and the order/answer files in $RD/orders. You cannot run anything;
judge from the code and tests. Spend your effort READING; keep your OUTPUT SHORT (hard cap ~400 words). Write to
$RD/orders/ACCEPTANCE.md: 1) verdict ACCEPT / ACCEPT WITH FIXES / REJECT; 2) a table: requirement (your reading of the
request) | MET / PARTLY / NOT MET | evidence (file:line or test name); 3) design soundness, at most 5 bullets; 4) up to 5
defects that matter to users, most severe first. No rewrites, no code, no praise. Then end your turn.

=== REQUEST ===
$PACKET
ACC
  echo "$(date -u +%FT%TZ) acceptance start" >> $RD/master.started
  # rc_session.sh starts from env -i: RC_ENV must be set here too (it was only set inside answer_questions, so with
  # zero question rounds the Opus session could not find `claude` and F2-2's acceptance died in 6 s — fixed 2026-10-16)
  export RC_ENV="$(printf '%s\n' HOME=$HOME USER=$USER LANG=C.UTF-8 TERM=xterm-256color "PATH=$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin" CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 DISABLE_AUTOUPDATER=1)"
  $B/bin/rc_session.sh "lb-$RID-accept" "$RD/repo" "$RD/orders/accept.prompt.md" "$RD/accept.json" 2400 -- \
    --model opus --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
    --disable-slash-commands --add-dir "$RD/orders" --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" \
    --disallowedTools "Edit(/$RD/repo/**)" Bash WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree 2> $RD/accept.stderr
  echo "$(date -u +%FT%TZ) acceptance done: $(grep -o -m1 -E 'ACCEPT WITH FIXES|ACCEPT|REJECT' $RD/orders/ACCEPTANCE.md 2>/dev/null)" >> $RD/master.started
fi
T1=$(date +%s)
jq -n --arg rid "$RID" --arg t "$T" --arg arm "S-$ARM" --argjson wall $((T1-T0)) \
  --argjson calls "$(ls $RD/exec/*.json 2>/dev/null | grep -c '/[0-9]*\.json')" \
  --argjson q "$(ls $RD/orders/questions-*.md 2>/dev/null | wc -l)" \
  '{run_id:$rid, task:$t, arm:$arm, master_exit:0, timed_out:($wall>='"${RUN_CAP:-7200}"'), wall_s:$wall, executor_calls:$calls, question_rounds:$q}' > $RD/master.summary.json
cat $RD/master.summary.json
