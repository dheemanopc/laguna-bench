#!/usr/bin/env bash
# t6_score.sh <run_dir> <outdir>
# Scores a T6 (test-writing) run: (1) source/alembic/existing tests unchanged vs base-T6,
# (2) new test files pass on a fresh DB, (3) mutmut kill rate over the T6 target modules
# with selection = baseline tests + the new test files (see bin/t6_mutmut.sh).
set -uo pipefail
run="$1"; out="$2"; base=$HOME/laguna-bench/wt/base-T6
mkdir -p "$out"
viol=$(diff -rq -x __pycache__ -x '*.pyc' "$base/src" "$run/src"; diff -rq -x __pycache__ "$base/alembic" "$run/alembic"; \
       for f in $(cd "$base" && find tests -name '*.py'); do cmp -s "$base/$f" "$run/$f" || echo "modified: $f"; done; \
       cmp -s "$base/pyproject.toml" "$run/pyproject.toml" || echo "modified: pyproject.toml")
if [ -n "$viol" ]; then echo "DISQUALIFIED (non-test changes):"; echo "$viol"; echo "$viol" > "$out/violations.txt"; exit 2; fi
new=$(cd "$run" && find tests -name 'test_*.py' | while read f; do [ -e "$base/$f" ] || echo "$f"; done | sort)
echo "new test files: $new" | tee "$out/new_tests.txt"
[ -z "$new" ] && { echo "no new tests"; exit 3; }
$HOME/laguna-bench/bin/run_tests.sh "$run" bench_tpl "lb_t6green_$$" -- -rfE $new > "$out/green.txt" 2>&1
grc=$?; tail -1 "$out/green.txt"
[ $grc = 0 ] || { echo "NEW TESTS NOT GREEN on unmodified source (rc=$grc)"; exit 4; }
$HOME/laguna-bench/bin/t6_mutmut.sh "$run" "$out/mutmut" $new
