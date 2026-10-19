#!/usr/bin/env bash
# score_task.sh <Tn> <run_dir> <outdir>      (T1..T5; T6 uses bin/t6_score.sh)
# Copies <run_dir> (no .git/.venv) to <outdir>/tree, then on fresh DBs cloned from the task template
# (alembic upgrade head first when meta.needs_migration != "no"):
#   1. hidden tests (~/laguna-bench/hidden/<Tn>, overlaid) + visible tests  -> must all pass
#   2. full suite with the overlay                                         -> red set minus known_red_base = NEW failures
#   3. T2 only: non-test source must differ from base (tests-only change = automatic fail)
set -uo pipefail
T="$1"; run="$2"; out="$3"; TD=$HOME/laguna-bench/tasks/$T; B=$HOME/laguna-bench/bin
tpl=$(python3 -c "import json;print(json.load(open('$TD/meta.json'))['db_template'])")
nm=$(python3 -c "import json;print(json.load(open('$TD/meta.json'))['needs_migration'])")
mig=""; [ "$nm" != "no" ] && mig="--migrate"
rm -rf "$out"; mkdir -p "$out/tree"
tar -C "$run" --exclude=.git --exclude=.venv --exclude=mutants --exclude=node_modules -cf - . | tar -C "$out/tree" -xf -
[ -d "$TD/visible" ] && cp -r "$TD/visible/." "$out/tree/"
vis=""; [ -d "$TD/visible" ] && vis=$(cd "$TD/visible" && find . -name 'test_*.py' | sed 's|^\./||')
$B/run_hidden.sh "$T" "$out/tree" "$tpl" "sc_${T,,}_h_$$" $mig -- $vis > "$out/hidden.txt" 2>&1; hrc=$?
FULL=1 $B/run_hidden.sh "$T" "$out/tree" "$tpl" "sc_${T,,}_f_$$" $mig > "$out/full.txt" 2>&1
grep -E "^(FAILED|ERROR) " "$out/full.txt" | awk '{print $2}' | sort -u > "$out/red.txt"
comm -23 "$out/red.txt" <(sort -u "$TD/known_red_base.txt") > "$out/new_failures.txt"
src_changed=yes
if [ "$T" = T2 ]; then
  d=$(diff -rq -x __pycache__ -x '*.pyc' "$HOME/laguna-bench/wt/base-T2/src" "$out/tree/src"; diff -rq "$HOME/laguna-bench/wt/base-T2/alembic" "$out/tree/alembic" | grep -v __pycache__)
  [ -z "$d" ] && src_changed=no
fi
{
  echo "task=$T template=$tpl migrate=${mig:-no}"
  echo "hidden+visible: $(tail -1 "$out/hidden.txt") (rc=$hrc)"
  echo "full suite: $(tail -1 "$out/full.txt")"
  echo "new failures vs known_red_base: $(wc -l < "$out/new_failures.txt")"; sed 's/^/  /' "$out/new_failures.txt"
  [ "$T" = T2 ] && echo "non-test source changed: $src_changed"
  if [ $hrc = 0 ] && [ ! -s "$out/new_failures.txt" ] && [ $src_changed = yes ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
} | tee "$out/score.txt"
