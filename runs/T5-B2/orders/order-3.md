# Work order 3 — verification only (no source changes expected)

The code from orders 1–2 looks good. Two verification steps from order 2 were not done. Please do them now and report exact outputs. Only change code if a step reveals a real problem (then explain it).

1. **Prove the new integration tests fail without the fix.**
   - `git stash push -- src/` (stash ONLY src changes; tests stay).
   - `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py` — report the pass/fail per test and the failure reason in one line each. In particular I need to see that `test_6_concurrent_fork_decision`, `test_8_concurrent_tags_add_remove`, `test_8_concurrent_distinct_removes` (and the distinct-adds test if present) fail on assertions (lost tags / multiple successes / forked chain), not merely on missing `revision`/`expected_revision` attributes. If one of them passes on the original code, strengthen it (e.g. more concurrency) until it fails without the fix and passes with it.
   - `git stash pop`; then `git status --short` and confirm all 4 src files are modified again.
2. **Full-suite regression check.**
   - With changes: `pytest -q -p no:cacheprovider tests/unit tests/integration 2>&1 | tail -60` — collect the list of FAILED/ERROR node ids.
   - Baseline: `git stash push -- src/`, run the same command but add `--deselect` / `--ignore` for `tests/integration/test_update_concurrency.py` and `tests/unit/test_tools_update_concurrency.py`, collect FAILED/ERROR ids, then `git stash pop`.
   - Report both lists and confirm the "with changes" set (excluding the two new files) is a subset of the baseline set. Any new failure must be investigated and fixed.
3. Run `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py` 3 times with changes applied to check flakiness; report results.
4. Final `ruff check src tests` and `mypy` results.
