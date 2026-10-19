#!/usr/bin/env bash
# prepare_run.sh <task Tn> <run_id> — build an isolated, HISTORY-LESS run directory for one benchmark run.
#   runs/<run_id>/repo   : `git archive <base>` of the task's base commit + fresh `git init` + ONE baseline commit
#                          (executors can diff their own work but cannot see future/solution commits — rev7 leakage rule)
#   runs/<run_id>/orders : work orders written by the Opus master (outside the repo)
#   runs/<run_id>/exec   : full executor JSON logs (stay local; master only sees compact summaries)
#   runs/<run_id>/run.env: per-run DSNs (fresh DB cloned from the task's migrated template), not visible in git
# Hidden tests are NEVER copied here; they are only added at scoring time (score_run.sh).
set -euo pipefail
T="$1"; RID="$2"; B=$HOME/laguna-bench; REPO=/codes/ai-work/memory-man
META=$B/tasks/$T/meta.json; [ -f "$META" ] || { echo "no meta for $T"; exit 1; }
BASE=$(jq -r .base_commit $META); TPL=$(jq -r '.db_template // "bench_tpl"' $META)
RD=$B/runs/$RID; [ -e "$RD" ] && { echo "run dir exists: $RD"; exit 2; }
mkdir -p $RD/repo $RD/orders $RD/exec
BASE_DIR=$(jq -r '.base_dir // empty' $META)
if [ -n "$BASE_DIR" ]; then   # feature built on a previous run's delivered working tree (e.g. F2 on F1-1)
  tar -C $B/$BASE_DIR --exclude=.git --exclude=.venv --exclude=__pycache__ --exclude=node_modules --exclude=CLAUDE.md --exclude=CONVENTIONS.md --exclude=KNOWN_RED_BASE.txt -cf - . | tar -x -C $RD/repo; BASE="dir:$BASE_DIR"
else git -C $REPO archive "$BASE" | tar -x -C $RD/repo; fi
# visible tests for this task (e.g. T2's single repro test), mirrored by repo-relative path
[ -d $B/tasks/$T/visible ] && cp -r $B/tasks/$T/visible/. $RD/repo/
# identical bench instructions for every run and both arms
cp $B/bench-CLAUDE.md $RD/repo/CLAUDE.md
[ -f $B/tasks/CONVENTIONS.md ] && cp $B/tasks/CONVENTIONS.md $RD/repo/CONVENTIONS.md
cd $RD/repo && git init -q && git config user.email bench@local && git config user.name bench \
  && git add -A && git commit -qm "baseline" && git rev-parse HEAD > $RD/baseline_sha
DB="lb_$(echo $RID | tr -c 'a-zA-Z0-9_\n' _)"
$B/bin/fresh_db_tpl.sh "$TPL" "$DB" > $RD/run.env
echo "export BENCH_DB=$DB" >> $RD/run.env
jq -n --arg t "$T" --arg r "$RID" --arg b "$BASE" --arg db "$DB" --arg tpl "$TPL" \
  '{task:$t,run_id:$r,base_commit:$b,db:$db,db_template:$tpl,created:(now|todate)}' > $RD/run.json
# web UI gates (tsc / next lint / next build) use the already-installed node_modules of the source repo (no npm download).
# Linked AFTER the baseline commit and git-excluded (a symlink is not matched by .gitignore's "node_modules/").
if [ -d $RD/repo/web ] && [ -d $REPO/web/node_modules ]; then ln -sfn $REPO/web/node_modules $RD/repo/web/node_modules; printf "web/node_modules\nweb/.next/\n" >> $RD/repo/.git/info/exclude; fi
echo "$RD"
