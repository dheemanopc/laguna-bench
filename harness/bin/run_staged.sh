#!/usr/bin/env bash
# run_staged.sh <task Fn> <run_id> [arm=F]
# Staged, supervised feature run (Anand 2026-10-16): Laguna does ALL the work, including niche work; an Opus ARCHITECT
# reviews every step and nothing moves on without APPROVE. Opus is read-heavy and output-capped (≤250-word reviews),
# so its INPUT tokens dominate, as Anand wants. Each Opus review is its own session, so its cost is measurable per stage.
#   Stage 1  analysis    — WHAT should change: restate every requirement, affected components, constraints found, risks
#   Stage 2  design      — HOW: data model, rules, interfaces (MCP + web API), UI, existing-data migration, errors
#   Stage 3  plan        — HOW IT INTEGRATES: touch points, sequencing, work packages (## WP<n>: title), test plan per WP
#   Stage 4  wp<n>       — implement each WP; the harness runs the gates (suite vs known red, ruff, mypy, alembic, web)
#                          and attaches the REAL output to the architect's code review (Laguna's claims are not trusted)
#   Stage 5  acceptance  — final Opus acceptance against the original request
# One Laguna session throughout (resumed), so it keeps its context. REVISE → findings go back as the next order
# (≤ MAX_ROUNDS per gate, then the run moves on with the open findings recorded). Stage markers in master.started
# let token_ledger.py split tokens and cost per stage.
set -uo pipefail
T="$1"; RID="$2"; ARM="${3:-F}"; B=$HOME/laguna-bench; RD=$B/runs/$RID
MAX_ROUNDS=${MAX_ROUNDS:-3}; RUN_CAP=${RUN_CAP:-21600}; DOCS=docs/feature
[ -d $RD/repo ] || $B/bin/prepare_run.sh $T $RID >/dev/null || exit 1
T0=$(date +%s); echo $((T0+RUN_CAP)) > $RD/deadline
ev() { echo "$(date -u +%FT%TZ) $*" >> $RD/master.started; }
ev "start (staged, arm $ARM)"
PACKET="$(cat $B/tasks/$T/packet.md)"
export PATH_GUARD=1
export EXTRA_EXEC_TOOLS=$(printf '%s\n' "Bash(mkdir:*)" "Bash(rm:*)" "Bash(mv:*)" "Bash(cp:*)" "Bash(touch:*)" "Bash(cat:*)" \
  "Bash(head:*)" "Bash(tail:*)" "Bash(wc:*)" "Bash(find:*)" "Bash(grep:*)" "Bash(sed:*)" "Bash(diff:*)" "Bash(sort:*)" "Bash(echo:*)" \
  "Bash(python:*)" "Bash(python3:*)" "Bash(git:*)" "Bash(cd:*)" \
  "Bash(npm run lint:*)" "Bash(npm run build:*)" "Bash(npx tsc:*)" "Bash(npx next:*)" "Bash(npx eslint:*)")
SETTINGS='{"autoMemoryEnabled":false,"claudeMdExcludes":["'$HOME'/.claude/CLAUDE.md","**/.claude/CLAUDE.md"]}'
export RC_ENV="$(printf '%s\n' HOME=$HOME USER=$USER LANG=C.UTF-8 TERM=xterm-256color "PATH=$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin" CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 DISABLE_AUTOUPDATER=1)"
N=0
laguna() {   # $1 = order text → next order file, run (resumes the same session)
  N=$((N+1)); printf '%s\n' "$1" > $RD/orders/order-$N.md
  $B/bin/run_executor.sh $ARM $RID $RD/orders/order-$N.md > $RD/exec-$N.summary.json
}
gates() {   # objective checks; output is attached to the architect's code review
  ( cd $RD/repo; V=$B/wt/lead/.venv/bin
    echo "## Harness gate results (run by the harness, not by the engineer)"
    echo "- ruff: $($V/ruff check src tests 2>&1 | tail -1)"
    echo "- mypy: $($V/mypy src 2>&1 | tail -1)"
    echo "- alembic heads: $(PYTHONPATH=src $V/alembic heads 2>&1 | grep -c '(head)')"
    echo "- tests added/changed: $(git status --short tests | wc -l) files"
    $B/bin/score_task.sh $T $RD/repo $RD/gate_out > /dev/null 2>&1
    echo "- full suite: $(grep '^full suite' $RD/gate_out/score.txt | cut -d: -f2-)"
    echo "- NEW failures vs known red: $(wc -l < $RD/gate_out/new_failures.txt)"; head -15 $RD/gate_out/new_failures.txt | sed 's/^/    /'
    if [ -n "$(git status --short web | grep -v node_modules)" ]; then
      echo "- web tsc: $(cd web && npx tsc --noEmit 2>&1 | tail -3 | tr '\n' ' ')"
      echo "- web build: $(cd web && npm run build 2>&1 | grep -E 'Compiled|Failed|rror' | head -3 | tr '\n' ' ')"
    else echo "- web: no changes"; fi
    echo; echo "## Change summary vs baseline (read-only)"; git diff --stat $(cat $RD/baseline_sha) | tail -20; git status --short | grep "^??" | head -30 ) > $RD/orders/gates-$1.md 2>&1
}
review() {   # $1 = stage, $2 = round, $3 = what to review → sets VERDICT; writes orders/review-<stage>-<round>.md
  local st=$1 r=$2 what=$3 out=$RD/orders/review-$1-$2.md
  cat > $RD/orders/review-$st-$r.prompt.md <<P
You are the ARCHITECT supervising an engineer who does all of the work on the feature below. This is the $st gate
(round $r). Review: $what
Read as much as you need (the repository at $RD/repo, the engineer's documents under $RD/repo/$DOCS, earlier reviews and
orders in $RD/orders). Judge against the REQUEST, the existing codebase and its conventions. Spend your effort READING;
keep your OUTPUT SHORT. Write to $out — first line exactly "VERDICT: APPROVE" or "VERDICT: REVISE", then at most 5
numbered findings, most important first, each one line with evidence (file:line, doc section or gate line). Hard cap 250
words. APPROVE only if the stage is good enough to build on; minor nits go in findings without blocking. No code, no
rewrites, no praise. Then end your turn.

=== REQUEST ===
$PACKET
P
  ev "review $st round $r start"
  $B/bin/rc_session.sh "lb-$RID-arch-$st-$r" "$RD/repo" "$RD/orders/review-$st-$r.prompt.md" "$RD/review-$st-$r.json" 1800 -- \
    --model opus --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
    --disable-slash-commands --add-dir "$RD/orders" --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" \
    --disallowedTools "Edit(/$RD/repo/**)" Bash WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree \
    2> $RD/review-$st-$r.stderr
  VERDICT=$(head -1 $out 2>/dev/null | grep -o -E 'APPROVE|REVISE'); [ -z "$VERDICT" ] && VERDICT=MISSING
  ev "review $st round $r: $VERDICT"
}
gate_loop() {   # $1 stage, $2 artifact description for the reviewer, $3 revise instruction suffix, $4 = "code" to run gates
  local st=$1 r=1
  while :; do
    [ "${4:-}" = code ] && gates $st-$r
    local what="$2"; [ "${4:-}" = code ] && what="$2 The harness gate output is in $RD/orders/gates-$st-$r.md (authoritative)."
    review $st $r "$what"
    [ "$VERDICT" = APPROVE ] && return 0
    [ $r -ge $MAX_ROUNDS ] && { ev "gate $st: moving on after $r rounds (open findings recorded)"; return 1; }
    [ $(( $(date +%s) - T0 )) -ge $((RUN_CAP-900)) ] && { ev "gate $st: run cap near, stopping"; return 2; }
    laguna "The architect reviewed your $st and asked for revisions:

$(cat $RD/orders/review-$st-$r.md 2>/dev/null || echo '(review missing; re-check your work against the request)')
$( [ "${4:-}" = code ] && { echo; cat $RD/orders/gates-$st-$r.md; } )

$3 When done, end your turn with a 3-line summary of what you changed."
    r=$((r+1))
  done
}
COMMON="You are the engineer for the feature below and you do all of the work: investigation, design, implementation,
tests and verification. An architect reviews every stage before you move on, so present your work clearly. Nobody
answers questions mid-stage: if something is ambiguous, state your interpretation and the alternatives in your document.
Shell: run commands plainly (no output redirection, no pipes into files); create files with the Write tool."

# ---- Stage 1: analysis ----
ev "stage analysis start"
laguna "$COMMON

STAGE 1 — ANALYSIS (what should change). Do NOT write code yet. Investigate the codebase and write $DOCS/01-analysis.md:
1) every requirement in the request, restated in your own words (one line each, numbered R1..Rn) — none may be dropped;
2) the components affected (tables and constraints, services, MCP tools, web API, web UI pages) with file paths;
3) existing behaviour or constraints that the feature collides with (with file:line);
4) risks and open questions with your recommended answer. Then end your turn.

=== REQUEST ===
$PACKET"
gate_loop analysis "the engineer's analysis $RD/repo/$DOCS/01-analysis.md: are ALL requirements captured faithfully, are the affected components and colliding constraints right?" \
  "Revise $DOCS/01-analysis.md accordingly (no code)."
# ---- Stage 2: design ----
ev "stage design start"
laguna "STAGE 2 — DESIGN (how). Still no code. Write $DOCS/02-design.md covering every requirement R1..Rn from your
analysis (map each R to the design element that satisfies it): data model and constraints, rules / state machine,
interfaces (MCP tools and web API, request/response and errors), web UI (pages, components, what the user sees),
what happens to existing data and in-flight items, and edge cases. Then end your turn."
gate_loop design "the engineer's design $RD/repo/$DOCS/02-design.md: does it satisfy every requirement R1..Rn in 01-analysis.md, is it sound and consistent with the codebase?" \
  "Revise $DOCS/02-design.md accordingly (no code)."
# ---- Stage 3: integration plan ----
ev "stage plan start"
laguna "STAGE 3 — INTEGRATION PLAN (how it fits in). Still no code. Write $DOCS/03-plan.md: the exact touch points (files to
create/modify), migration ordering, and the work packages in build order, each as a heading '## WP<n>: <title>' with: scope,
files, the requirements it delivers, and its test plan (test names and what each proves). Keep each WP reviewable
(roughly migrations / backend services / MCP tools / web API / web UI). Then end your turn."
gate_loop plan "the engineer's integration plan $RD/repo/$DOCS/03-plan.md: are the work packages complete (every requirement delivered by some WP), correctly ordered, each with a test plan that would catch real defects?" \
  "Revise $DOCS/03-plan.md accordingly (no code)."
# ---- Stage 4: work packages ----
WPS=$(grep -o -E '^## WP[0-9]+' $RD/repo/$DOCS/03-plan.md 2>/dev/null | grep -o -E '[0-9]+' | sort -n | uniq)
[ -z "$WPS" ] && { ev "no WPs found in plan"; WPS=1; }
for w in $WPS; do
  [ $(( $(date +%s) - T0 )) -ge $((RUN_CAP-900)) ] && { ev "run cap near before wp$w"; break; }
  ev "stage wp$w start"
  laguna "STAGE 4 — implement WP$w exactly as planned in $DOCS/03-plan.md, including its tests. Run the tests you wrote and
the relevant existing ones; fix what fails. Keep $DOCS in sync if you deviate. Then end your turn with what you built and the
test commands + results."
  gate_loop wp$w "the implementation of WP$w (see $RD/repo/$DOCS/03-plan.md and the code changes): does it deliver its planned scope and tests, is it correct, does it follow the codebase's conventions?" \
    "Fix these in the code and tests for WP$w, re-run the tests." code
done
# ---- Stage 5: acceptance ----
ev "stage acceptance start"; gates final
cat > $RD/orders/accept.prompt.md <<P
You are the product owner doing the final ACCEPTANCE of this feature. Read whatever you need: the repository at
$RD/repo (the engineer's documents under $DOCS, code, migrations, tests, web UI), the architect's reviews and the harness
gate output ($RD/orders/gates-final.md) in $RD/orders. Spend your effort READING; keep OUTPUT SHORT (hard cap ~400 words).
Write to $RD/orders/ACCEPTANCE.md: 1) verdict ACCEPT / ACCEPT WITH FIXES / REJECT; 2) table: requirement | MET / PARTLY /
NOT MET | evidence; 3) up to 5 defects that matter to users, most severe first. No code, no praise. Then end your turn.

=== REQUEST ===
$PACKET
P
$B/bin/rc_session.sh "lb-$RID-accept" "$RD/repo" "$RD/orders/accept.prompt.md" "$RD/accept.json" 2400 -- \
  --model opus --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --disable-slash-commands --add-dir "$RD/orders" --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" \
  --disallowedTools "Edit(/$RD/repo/**)" Bash WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree 2> $RD/accept.stderr
ev "acceptance done: $(grep -o -m1 -E 'ACCEPT WITH FIXES|ACCEPT|REJECT' $RD/orders/ACCEPTANCE.md 2>/dev/null)"
jq -n --arg rid "$RID" --arg t "$T" --arg arm "staged-$ARM" --argjson wall $(( $(date +%s)-T0 )) --argjson orders $N \
  '{run_id:$rid, task:$t, arm:$arm, wall_s:$wall, laguna_orders:$orders}' > $RD/master.summary.json
cat $RD/master.summary.json
