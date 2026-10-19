#!/usr/bin/env bash
# run_tree.sh <task Fn> <run_id>  — "tree" shape for a real feature (Anand 2026-10-16):
#   1. Opus  = PRODUCT OWNER: turns the raw backlog idea into a business brief (intent, user stories, acceptance
#              criteria, out of scope). No design, no code.
#   2. Sonnet = DA (design authority / tech lead): designs the whole feature as work packages, picks only a FEW for
#              this round, and drives TWO Laguna XS developers in parallel (dispatch_devs.sh: dev1 on GPU0, dev2 on
#              GPU1), reviews their diffs, may run tests/lint itself, sends fixes. Cannot edit code.
#   3. Opus  = ACCEPTANCE: judges the delivered packages against its brief (business behaviour only).
# All Claude sessions are interactive with Remote Control (rc_session.sh); developers (dummy token) cannot attach RC.
set -uo pipefail
T="$1"; RID="$2"; B=$HOME/laguna-bench; RD=$B/runs/$RID
[ -d $RD/repo ] || $B/bin/prepare_run.sh $T $RID >/dev/null || exit 1
EMPTY=$B/empty; mkdir -p $EMPTY; : > $EMPTY/aws_config; : > $EMPTY/aws_creds
VENV=$B/wt/lead/.venv; PACKET="$(cat $B/tasks/$T/packet.md)"
SETTINGS='{"autoMemoryEnabled":false,"claudeMdExcludes":["'$HOME'/.claude/CLAUDE.md","**/.claude/CLAUDE.md"]}'
NOWEB=(WebSearch WebFetch NotebookEdit Agent Task EnterPlanMode ExitPlanMode EnterWorktree ExitWorktree)
BASEENV=(HOME="$HOME" USER="$USER" LANG=C.UTF-8 TERM=xterm-256color
  AWS_CONFIG_FILE=$EMPTY/aws_config AWS_SHARED_CREDENTIALS_FILE=$EMPTY/aws_creds AWS_EC2_METADATA_DISABLED=true
  CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX=laguna-bench DISABLE_AUTOUPDATER=1)
log() { echo "$(date -u +%FT%TZ) $*" >> $RD/tree.log; }
T0=$(date +%s)

# ---- 1. Opus product owner → BRIEF.md ----
cat > $RD/orders/owner.prompt.md <<P
You are the PRODUCT OWNER for a new feature in this repository (Memsys, a team memory service with MCP tools).
Business understanding is your territory; engineers will do design and implementation.
Read enough of the repository docs and code to understand the product and the mind-map feature, then turn the raw
idea below into a business brief. Write it with the Write tool to $RD/orders/BRIEF.md and end your turn.

The brief must contain: the problem and who it is for; user stories; the business rules (what a work item is, which
states and transitions make sense, who may change what, what the audit trail must let someone answer); numbered,
testable ACCEPTANCE CRITERIA phrased as observable behaviour; and what is explicitly out of scope.
Do NOT design the implementation (no schemas, no function names, no file plans). Keep it to what a business owner decides.

=== RAW IDEA ===
$PACKET
P
if [ -s $RD/orders/BRIEF.md ]; then log "owner skipped (BRIEF.md exists)"; else
log "owner start"
export RC_ENV="$(printf '%s\n' "${BASEENV[@]}" "PATH=$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin")"
$B/bin/rc_session.sh "lb-$RID-owner" "$RD/repo" "$RD/orders/owner.prompt.md" "$RD/owner.json" 1800 -- \
  --model opus --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --disable-slash-commands --add-dir "$RD/orders" --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" \
  --disallowedTools "Edit(/$RD/repo/**)" "${NOWEB[@]}" 2> $RD/owner.stderr
[ -s $RD/orders/BRIEF.md ] || { log "owner produced no BRIEF.md"; exit 1; }
log "owner done ($(( $(date +%s)-T0 ))s)"; fi

# ---- 2. Sonnet DA drives two XS developers ----
DA_CAP=${DA_CAP:-9000}; TD=$(date +%s); echo $((TD+DA_CAP)) > $RD/deadline
cat > $RD/orders/da.prompt.md <<P
You are the DESIGN AUTHORITY (tech lead) for one feature on this repository. You do NOT write code yourself.
Two developer engineers (dev1 and dev2) make every code change, working AT THE SAME TIME on the same working tree.

Input: the product owner's business brief at $RD/orders/BRIEF.md (business intent is the owner's call — if the brief
is ambiguous, choose the most reasonable reading and record it). Follow CONVENTIONS.md and the design docs.

Your job, in order:
1. Design the whole feature: write $RD/orders/DESIGN.md — data model + migration, service-layer rules (transitions,
   permissions, audit), MCP tool contracts, error mapping, tests; split into numbered WORK PACKAGES (WP1..WPn) with
   dependencies. The web UI cannot be built or tested here (no node_modules): design it, but do not schedule it.
2. Pick only a FEW packages for this round (2, at most 3) — the foundation a later round would build on — and say
   which brief acceptance criteria they deliver. Assign them so dev1 and dev2 can work in parallel on DISJOINT files
   (exactly one of them owns the migration; if one needs the other's code, fix the interface — signatures, table and
   column names — in both orders so neither waits).
3. Delegate: write self-contained orders to NEW files $RD/orders/dev1-<n>.md / dev2-<n>.md (never overwrite), then run
     $B/bin/dispatch_devs.sh $RID <dev1 order or -> <dev2 order or ->
   (Bash timeout 7500000 ms; it runs both developers in parallel and returns one JSON summary per developer;
   later orders resume the same developer's session). Developers see only the repo, CLAUDE.md, CONVENTIONS.md and
   their order — not the brief or your design doc — so include everything they need.
4. Review: git -C $RD/repo diff / status, read the code, and run the checks yourself: pytest (targeted + full suite
   \`pytest -q\`), \`ruff check src tests\`, \`alembic upgrade head\` (your own test database is configured). Pre-existing
   failures are listed in $RD/orders/known_red_base.txt — anything else failing is new. Send precise fixes in new orders.
5. Repeat until the chosen packages are done well. Be efficient: few, high-quality round-trips. Hard stop: $((DA_CAP/60)) min.
Rules: you cannot edit repository files; no web access. Nobody is watching this session to answer questions or grant
permissions — never stop to ask; decide and continue until the work is done.
Tools: read files with Read/Grep/Glob (not cat/ls). Bash is allowed ONLY for these commands, each run as a single plain
command — no \`cd\`, no \`;\`/\`&&\`/pipes, no redirections (anything else is denied):
  $B/bin/dispatch_devs.sh ...   |   git -C $RD/repo diff ...   |   git -C $RD/repo status ...
  pytest ...   |   python -m pytest ...   |   ruff ...   |   alembic ...     (these run in the repository root)
Final reply: packages delivered (with the acceptance criteria they cover), round-trips per developer, what you
verified yourself (commands + results), remaining concerns, and what the next round should build.
P
cp $B/tasks/$T/known_red_base.txt $RD/orders/ 2>/dev/null
cp $RD/run.env $RD/orders/.da.env 2>/dev/null
DAENV=("${BASEENV[@]}" "PATH=$VENV/bin:$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin"
  PYTHONPATH="$RD/repo/src" PYTHONDONTWRITEBYTECODE=1 BASH_DEFAULT_TIMEOUT_MS=7500000 BASH_MAX_TIMEOUT_MS=7500000)
while IFS= read -r l; do l=${l#export }; DAENV+=("${l//\'/}"); done < $RD/run.env
export RC_ENV="$(printf '%s\n' "${DAENV[@]}")"
log "DA start"
$B/bin/rc_session.sh "lb-$RID-da" "$RD/repo" "$RD/orders/da.prompt.md" "$RD/da.json" $DA_CAP -- \
  --model sonnet --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --disable-slash-commands --add-dir "$RD/orders" \
  --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" "Bash($B/bin/dispatch_devs.sh:*)" \
    "Bash(git -C $RD/repo diff:*)" "Bash(git -C $RD/repo status:*)" "Bash(pytest:*)" "Bash(python -m pytest:*)" \
    "Bash(ruff:*)" "Bash(alembic:*)" \
  --disallowedTools "Edit(/$RD/repo/**)" "${NOWEB[@]}" 2> $RD/da.stderr
DARC=$?
for s in $(tmux ls -F '#S' 2>/dev/null | grep "^rc-lb-$RID\.dev"); do tmux kill-session -t "$s"; done
for p in $(pgrep -f "bin/(run_executor|rc_session|dispatch_devs)\.sh .*$RID"); do kill "$p" 2>/dev/null; done
log "DA done rc=$DARC ($(( $(date +%s)-TD ))s)"

# ---- 3. Opus acceptance ----
(cd $RD/repo && git add -N . && git diff > $RD/feature.diff)
cat > $RD/orders/accept.prompt.md <<P
You are the PRODUCT OWNER again. Your brief is $RD/orders/BRIEF.md. The tech lead's design is $RD/orders/DESIGN.md; this
round delivered only some work packages (see the tech lead's report below). The full change is $RD/feature.diff and the
code is in this repository. Judge, as the business owner, ONLY what this round claims to deliver:
for each acceptance criterion it claims, say MET / PARTLY / NOT MET with evidence (file:line or test name); flag any
place where the design or code contradicts the business intent of your brief; list what is still missing for the
whole feature. Write it to $RD/orders/ACCEPTANCE.md with an overall verdict (ACCEPT / ACCEPT WITH FIXES / REJECT) and end.
Do not write code. Tech lead's report:
$(jq -r '.result // ""' $RD/da.json 2>/dev/null | head -c 6000)
P
export RC_ENV="$(printf '%s\n' "${BASEENV[@]}" "PATH=$HOME/.local/bin:$(dirname "$(command -v node)"):/usr/local/bin:/usr/bin:/bin")"
log "acceptance start"
$B/bin/rc_session.sh "lb-$RID-accept" "$RD/repo" "$RD/orders/accept.prompt.md" "$RD/accept.json" 1800 -- \
  --model opus --setting-sources project --settings "$SETTINGS" --strict-mcp-config --mcp-config '{"mcpServers":{}}' \
  --disable-slash-commands --add-dir "$RD/orders" --allowedTools Read Grep Glob "Edit(/$RD/orders/**)" \
  --disallowedTools "Edit(/$RD/repo/**)" "${NOWEB[@]}" 2> $RD/accept.stderr
log "acceptance done; total $(( $(date +%s)-T0 ))s"
jq -n --arg rid "$RID" --arg t "$T" --argjson darc $DARC --argjson wall $(( $(date +%s)-T0 )) \
  --argjson d1 "$(ls $RD.dev1/exec/*.json 2>/dev/null | grep -c '/[0-9]*\.json')" --argjson d2 "$(ls $RD.dev2/exec/*.json 2>/dev/null | grep -c '/[0-9]*\.json')" \
  '{run_id:$rid, task:$t, shape:"opus-owner > sonnet-DA > 2x laguna-xs", da_exit:$darc, wall_s:$wall, dev1_calls:$d1, dev2_calls:$d2}' > $RD/tree.summary.json
cat $RD/tree.summary.json
