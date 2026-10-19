# Work order 3 — verification evidence only (no feature changes)

Your last report did not include ruff/mypy output or the actual failing-test ids. Please run and
paste the literal output (trimmed to the relevant lines):

1. `ruff check src tests` — paste output. If it reports anything in
   `tests/integration/test_references_access_rule.py`, `src/mem_mcp/teams/references.py`,
   `src/mem_mcp/mcp/tools/refs_in.py` or `refs_out.py`, fix it (also run `ruff format --check` on those 4 files and format them if needed).
2. `mypy` (project config) — paste the summary line and any errors in the 4 files above; fix errors in those files
   (e.g. if tests are type-checked, `isinstance`-narrow tool outputs to `RefsInOutput`/`RefsOutOutput`).
3. Full suite before/after, with ids:
   - `git stash push -u && pytest -q -p no:cacheprovider tests 2>&1 | grep -E "^(FAILED|ERROR)" | sort > /tmp/claude-exec-before.txt; tail -1` of that run's summary
   - `git stash pop` (verify `git status` shows the 4 files again)
   - same command → `/tmp/claude-exec-after.txt`
   - `diff /tmp/claude-exec-before.txt /tmp/claude-exec-after.txt` — paste the diff (and both summary lines).
   Note: some pre-existing tests are flaky/order-dependent; if the diff shows a test failing only
   after, re-run that test alone on both versions and report.
4. Re-run `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_rule.py` and paste the summary line.
