#!/usr/bin/env bash
# run_verify.sh <run_id> <verifier arms...>   e.g. run_verify.sh F1-1 D P
# Anand's 2026-10-16 plan, verification leg: Sonnet writes a VERIFICATION PLAN from the brief + design only
# (it may NOT read the implementation), then each verifier model on the GPU executes that plan against a private
# copy of the delivered code (own DB; may add tests under tests/verify/, must not touch src/), writes VERIFY_REPORT.md.
# The harness then RE-RUNS each verifier's tests itself (verifier claims are not trusted) and Sonnet gives only a
# final PASS/FAIL from reports + harness results.
# Env switches (single-GPU box: verifiers run one model at a time):
#   REUSE_PLAN=1   keep the existing VERIFY_PLAN.md (skip step 1)
#   NO_DECIDE=1    run verifiers + harness re-run only (skip step 4)
#   ONLY_DECIDE=1  skip steps 1-3, just take the Sonnet decision over the given arms' existing results
# Ground truth for scoring: the Opus ACCEPTANCE.md of that run.
set -uo pipefail
RID="$1"; shift; ARMS=("$@"); B=$HOME/laguna-bench; RD=$B/runs/$RID; VD=$B/verify/$RID; mkdir -p $VD   # outside runs/ so the plan writer can be denied all of runs/
EMPTY=$B/empty; VENV=$B/wt/lead/.venv
SETTINGS='{"autoMemoryEnabled":false,"claudeMdExcludes":["'$HOME'/.claude/CLAUDE.md","**/.claude/CLAUDE.md"]}'
NOWEB=(WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree)
BASEENV=(HOME="$HOME" USER="$USER" LANG=C.UTF-8 TERM=xterm-256color
  "PATH=$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin"
  AWS_CONFIG_FILE=$EMPTY/aws_config AWS_SHARED_CREDENTIALS_FILE=$EMPTY/aws_creds AWS_EC2_METADATA_DISABLED=true
  CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=laguna-bench DISABLE_AUTOUPDATER=1)
log() { echo "$(date -u +%FT%TZ) $*" | tee -a $VD/verify.log; }
SONNET=(--model sonnet --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}'
  --disable-slash-commands)
# ---- 1. Sonnet verification plan (blind to the implementation) ----
mkdir -p $VD/spec; cp $RD/orders/BRIEF.md $RD/orders/DESIGN.md $VD/spec/; cp $RD/repo/CONVENTIONS.md $RD/repo/CLAUDE.md $VD/spec/ 2>/dev/null
cat > $VD/plan.prompt.md <<P
You are the tech lead. Developers have implemented work packages WP1 and WP2 of the design in $VD/spec/DESIGN.md
(business brief: $VD/spec/BRIEF.md). You will NOT read their code. Instead write a VERIFICATION PLAN that an independent
verifier engineer will execute against the delivered code, to decide pass/fail for this round.
The verifier can read the repository, run pytest/alembic/ruff/mypy against its own test database, and ADD new test files
under tests/verify/ (it must not change src/ or existing tests). It sees only the repo and your plan.
Write the plan with the Write tool to $VD/VERIFY_PLAN.md and end your turn. The plan must be concrete and executable:
numbered checks (V1..Vn), each with: the brief acceptance criterion / design rule it covers, the exact scenario
(setup, action, expected observable result), and how to check it (which test to write or command to run). Cover the
business rules that WP1+WP2 claim (states/transitions, reasons, permissions, history append-only and complete, tenant
isolation, concurrency guard, archived maps, error mapping) and the project's own gates (full suite vs pre-existing
failures, ruff, mypy, alembic single head, tenant-scope lint). Prefer checks that would catch a REAL regression.
Nobody will answer questions; do not ask any.
P
export RC_ENV="$(printf '%s\n' "${BASEENV[@]}")"
if [ "${REUSE_PLAN:-}${ONLY_DECIDE:-}" = "" ] || [ ! -s $VD/VERIFY_PLAN.md ]; then
log "plan start"
$B/bin/rc_session.sh "lb-$RID-vplan" "$VD/spec" "$VD/plan.prompt.md" "$VD/plan.json" 1800 -- "${SONNET[@]}" \
  --add-dir "$VD" --allowedTools Read Grep Glob "Edit(/$VD/**)" --disallowedTools "Read(/$B/runs/**)" "${NOWEB[@]}" 2> $VD/plan.stderr
[ -s $VD/VERIFY_PLAN.md ] || { log "no VERIFY_PLAN.md"; exit 1; }
log "plan done ($(grep -c -E '^#+ *V[0-9]+|^\*\*V[0-9]+|^V[0-9]+' $VD/VERIFY_PLAN.md) checks)"
else log "reusing existing VERIFY_PLAN.md"; fi
if [ -z "${ONLY_DECIDE:-}" ]; then
# ---- 2. verifiers in parallel, each on a private copy ----
pids=()
for A in "${ARMS[@]}"; do
  SR=$B/runs/$RID.verify$A; rm -rf $SR; mkdir -p $SR/orders $SR/exec $SR/repo
  tar -C $RD/repo --exclude=.venv --exclude=__pycache__ -cf - . | tar -C $SR/repo -xf -
  cp $RD/baseline_sha $SR/; echo $(( $(date +%s)+${VERIFY_CAP:-3600} )) > $SR/deadline
  DB="lb_$(echo $RID.verify$A | tr -c 'a-zA-Z0-9_\n' _)"; $B/bin/fresh_db_tpl.sh bench_tpl "$DB" > $SR/run.env; echo "export BENCH_DB=$DB" >> $SR/run.env
  (cd $SR/repo && git add -A >/dev/null 2>&1 && git -c user.email=b@l -c user.name=b commit -qm "delivered code under verification" && git rev-parse HEAD > $SR/verified_sha)
  cp $B/tasks/F1/known_red_base.txt $SR/repo/KNOWN_RED_BASE.txt 2>/dev/null
  { echo "You are an independent VERIFICATION engineer. Another team delivered the code in this repository. Execute the"
    echo "verification plan below against it and report honestly. Rules: do NOT modify anything under src/, alembic/ or"
    echo "existing tests — you may only ADD new test files under tests/verify/ (and a conftest there if needed). Run the"
    echo "checks yourself (pytest, alembic upgrade head, ruff check src tests, mypy). Pre-existing failures are listed in"
    echo "KNOWN_RED_BASE.txt. Nobody will answer questions. Write VERIFY_REPORT.md in the repository root: for every check"
    echo "V1..Vn: PASS / FAIL / NOT RUN, the exact command you ran and the relevant output lines; then a list of defects"
    echo "found (with file:line), and an overall verdict. A FAIL that shows a real defect is a good outcome — do not fix it."
    echo "Shell rules: run each command plainly (no output redirection to files, no pipes, no chained commands with && or ;)."
    echo "A denied command means only that exact form is blocked; pytest, alembic, ruff, mypy, git, ls, cat all work. Create"
    echo "files with the Write tool. Write VERIFY_REPORT.md EARLY and update it as you go, so a report exists even if you run out of time."
    echo; echo "=== VERIFICATION PLAN ==="; cat $VD/VERIFY_PLAN.md; } > $SR/orders/order-1.md
  log "verifier $A start"
  ( $B/bin/run_executor.sh $A $RID.verify$A $SR/orders/order-1.md > $SR/last.json 2>&1; log "verifier $A done" ) &
  pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
# ---- 3. harness re-runs each verifier's tests (claims not trusted) ----
for A in "${ARMS[@]}"; do
  SR=$B/runs/$RID.verify$A; (
    cd $SR/repo; set -a; . $SR/run.env; set +a
    echo "src/alembic/existing-test changes vs delivered code:"; git diff --stat $(cat $SR/verified_sha) -- src alembic tests ':!tests/verify' | tail -3
    echo "--- harness re-run of tests/verify:"; [ -d tests/verify ] && PATH=$VENV/bin:$PATH PYTHONPATH=$SR/repo/src timeout 900 pytest -q -p no:cacheprovider tests/verify 2>&1 | grep -E "^(FAILED|ERROR)|passed|failed|error" | tail -40 || echo "(no tests/verify)"
  ) > $SR/harness_rerun.txt 2>&1
  log "harness re-run $A: $(tail -1 $SR/harness_rerun.txt)"
done
fi   # ONLY_DECIDE
[ -n "${NO_DECIDE:-}" ] && { log "NO_DECIDE set — stopping before the decision"; exit 0; }
# ---- 4. Sonnet final pass/fail ----
{ echo "You are the tech lead. Independent verifiers executed your plan ($VD/VERIFY_PLAN.md) against the delivered code."
  echo "For each verifier below you have its report and the HARNESS re-run of its tests (the harness result is authoritative"
  echo "where they disagree). Give ONLY a final decision for this round: PASS or FAIL, the decisive defects (if any), and"
  echo "how much you trust each verifier's report (did its claims match the harness?). Write it to $VD/DECISION.md and end."
  for A in "${ARMS[@]}"; do SR=$B/runs/$RID.verify$A; echo; echo "=== VERIFIER $A REPORT ==="; head -c 20000 $SR/repo/VERIFY_REPORT.md 2>/dev/null || echo "(no report)"
    echo; echo "=== HARNESS RE-RUN $A ==="; cat $SR/harness_rerun.txt; done; } > $VD/decide.prompt.md
log "decision start"
$B/bin/rc_session.sh "lb-$RID-vdecide" "$VD/spec" "$VD/decide.prompt.md" "$VD/decide.json" 1200 -- "${SONNET[@]}" \
  --add-dir "$VD" --allowedTools Read Grep Glob "Edit(/$VD/**)" --disallowedTools "Read(/$RD/repo/**)" "${NOWEB[@]}" 2> $VD/decide.stderr
log "decision done: $(grep -o -m1 -E '\b(PASS|FAIL)\b' $VD/DECISION.md 2>/dev/null)"
