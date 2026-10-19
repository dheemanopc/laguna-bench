#!/usr/bin/env bash
# task_gate.sh <run_id> <key> <files_csv> <tests_csv>
# F2-4 per-TASK gate (seconds, not minutes): checks only what this task owns, because other tasks are editing the same
# tree at the same time. The full suite / full mypy / web build run only at package milestones (milestone_gate.sh).
#   ruff on the task's .py files; mypy src filtered to the task's files; web tsc filtered to the task's files;
#   the task's tests on a fresh migrated DB; RED FLAGS = weakened checks in the task's diff or any lint/type config change.
# Prints a markdown report; exit 0 = pass, 1 = fail. mypy runs under a lock (shared cache).
set -uo pipefail
RID="$1"; KEY="$2"; FILES="$3"; TESTS="$4"; B=$HOME/laguna-bench; RD=$B/runs/$RID; V=$B/wt/lead/.venv/bin
cd $RD/repo; IFS=, read -ra F <<< "$FILES"; IFS=, read -ra TS <<< "$TESTS"; fail=0
PY=(); WEB=(); for f in "${F[@]}"; do [ -f "$f" ] || continue; case "$f" in *.py) PY+=("$f");; web/*.ts|web/*.tsx) WEB+=("$f");; esac; done
echo "## Gate for $KEY (harness-run)"
missing=(); for f in "${F[@]}"; do [ -e "$f" ] || missing+=("$f"); done
[ ${#missing[@]} -gt 0 ] && echo "- note: planned files not present: ${missing[*]}"
if [ ${#PY[@]} -gt 0 ]; then
  r=$($V/ruff check "${PY[@]}" 2>&1); if echo "$r" | grep -q "All checks passed"; then echo "- ruff: clean"; else fail=1; echo "- ruff: FAIL"; echo "$r" | head -20 | sed 's/^/    /'; fi
  m=$(flock $RD/.mypy.lock $V/mypy src 2>&1 | grep -F -f <(printf '%s:\n' "${PY[@]}") | head -25)
  if [ -n "$m" ]; then fail=1; echo "- mypy (this task's files): FAIL"; echo "$m" | sed 's/^/    /'; else echo "- mypy (this task's files): clean"; fi
fi
if [ ${#WEB[@]} -gt 0 ]; then
  t=$(cd web && flock $RD/.tsc.lock npx tsc --noEmit 2>&1 | grep -F -f <(printf '%s\n' "${WEB[@]#web/}") | head -20)
  if [ -n "$t" ]; then fail=1; echo "- web tsc (this task's files): FAIL"; echo "$t" | sed 's/^/    /'; else echo "- web tsc (this task's files): clean"; fi
fi
PT=(); for t in "${TS[@]}"; do [ -n "$t" ] && [ -e "$t" ] && [[ "$t" == *.py ]] && PT+=("$t"); done
if [ ${#PT[@]} -gt 0 ]; then
  o=$($B/bin/run_tests.sh $RD/repo bench_tpl "g_$(echo "${RID}_$KEY" | tr -c 'a-zA-Z0-9_\n' _ | tr A-Z a-z)" --migrate -- -rfE "${PT[@]}" 2>&1); rc=$?
  last=$(echo "$o" | grep -E "passed|failed|error|no tests ran" | tail -1)
  if [ $rc -ne 0 ]; then fail=1; echo "- tests: FAIL — $last"; echo "$o" | grep -E "^(FAILED|ERROR) |ALEMBIC FAILED|Error|assert" | head -20 | sed 's/^/    /'
  else echo "- tests: $last"; fi
  echo "$o" | grep -q "skipped" && echo "    (some tests skipped — check they are not skipped on purpose)"
else
  [ -n "$TESTS" ] && { fail=1; echo "- tests: FAIL — none of the planned test files exist ($TESTS)"; } || echo "- tests: none planned"
fi
# red flags: weakened checks in this task's diff; lint/type config edits anywhere (2026-10-19: allow-list asyncpg import)
git add -N -- "${F[@]}" 2>/dev/null
flags=$(git diff -U0 HEAD -- "${F[@]}" 2>/dev/null | grep -E '^\+' | grep -v '^+++' | grep -v -E 'import asyncpg\s+# type: ignore\[import-untyped\]' | grep -n -E '#\s*noqa|type:\s*ignore|pytest\.mark\.(skip|xfail)|@pytest\.skip|pytest\.skip\(|eslint-disable|@ts-ignore|@ts-expect-error' | head -5)
cfg=$(git status --porcelain -- pyproject.toml setup.cfg mypy.ini ruff.toml tools/ web/tsconfig.json 'web/.eslintrc*' web/eslint.config.mjs 2>/dev/null | head -5)
if [ -n "$flags$cfg" ]; then fail=1; echo "- RED FLAG: weakened checks or lint/type config changed — remove them (the harness rejects these):"
  [ -n "$flags" ] && echo "$flags" | sed 's/^/    added: /'; [ -n "$cfg" ] && echo "$cfg" | sed 's/^/    config: /'; fi
[ $fail = 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit $fail
