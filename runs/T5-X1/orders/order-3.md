# Work order 3 — Revert edit to an existing test; deliver the verification evidence

## 1. Do not modify existing tests (hard rule)
You edited `tests/unit/test_web_memories_handler.py` (an existing test). That is not allowed. Revert it exactly:
`git checkout -- tests/unit/test_web_memories_handler.py`

The test broke because `MemoryUpdateOutput.revision` is a required field and existing callers/tests construct `MemoryUpdateOutput` without it. Fix on the source side instead, for backward compatibility: in `src/mem_mcp/mcp/tools/update.py` declare `revision: str = ""` on `MemoryUpdateOutput` (the tool itself always sets a real revision on both paths). Then confirm `tests/unit/test_web_memories_handler.py` passes **unmodified**. Check `git status` / `git diff --stat` afterwards: the only modified pre-existing files must be the 4 src files; the only other changes are your 2 new test files.

Also grep the rest of `tests/` and `src/` for other constructions of `MemoryUpdateOutput(` / `MemoryRecord(` to make sure nothing else depends on new required fields.

## 2. mypy on your new test files
You reported mypy errors in test files. Fix those in **your new files only** (`tests/unit/test_update_revision.py`, `tests/integration/test_update_concurrency.py`), e.g. `assert exc.value.data is not None` before indexing. Don't touch other tests. Report `ruff check src tests` and `mypy` output (if mypy's configured scope doesn't include tests, also run `mypy tests/unit/test_update_revision.py tests/integration/test_update_concurrency.py` and report).

## 3. Verification evidence — still missing from your last report, required now
Report exact commands and their final summary lines:
a. `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_web_memories_handler.py tests/unit/test_update_revision.py tests/integration/test_update_concurrency.py`
b. **Prove the new tests catch the bug against the old code**: `git stash push -- src/`, then `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py -rA 2>&1 | tail -40`; report which tests fail and the failure reason for (i) the concurrent tag-add test, (ii) the concurrent tag-remove test, (iii) the concurrent versioned-fork test, (iv) the sequential "update old superseded id" tests. Then `git stash pop` and show `git status`. (If a test passes against the old code, tell me which and why.)
c. Full suite baseline vs after: with src stashed run `pytest -q -p no:cacheprovider -rfE 2>&1 | grep -E '^(FAILED|ERROR)' | sort > <scratch>/before.txt` ; restore src; same into `after.txt`; then `comm -13 before.txt after.txt` (new failures) and report its output verbatim plus the summary line of both runs. Note: new test files exist in both runs; failures of *your* new tests in the "before" run are expected — exclude them from the comparison and say so. If the pre-existing failures are order/flaky-dependent (e.g. `tenants_email_key` duplicates), run the "after" run twice and report.
