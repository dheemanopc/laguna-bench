# Work order 2 — complete the regression tests + full verification

The source changes from order 1 (`teams/references.py`, `refs_in.py`, `refs_out.py`) look good —
do NOT change them unless a test below reveals a real bug (if so, explain).

Extend `tests/integration/test_references_access_rule.py` (only this file):

1. **refs_in / refs_out tool tests (missing).** Call `RefsInTool()` / `RefsOutTool()` from
   `mem_mcp.mcp.tools.refs_in` / `refs_out` with a `ToolContext` built like other tool tests do
   (grep `ToolContext(` in `tests/` for an example; `ToolDeps(embeddings=<stub>, audit=NoopAuditLogger(),
   quotas=NoopQuotas())`, `db_pool=pg_pool`, `tenant_id=<backfill user>`). Setup: backfill-style
   user U (no UETA row) with memories A, B in U's team; stranger S (own team) with memory X.
   References: B→A, X→A, A→X (insert via `insert_reference`).
   - `memsys_refs_in(A)` as U → `accessible_count == 1`, refs contain B only,
     `inaccessible_count == 1`, X's UUID appears nowhere in the output.
   - `memsys_refs_out(A)` as U → refs_out of A is [X] → `accessible_count == 0`,
     `inaccessible_count == 1`, X's UUID not in output. Also `memsys_refs_out(B)` as U →
     A listed as accessible.
   Assert on output fields, not just "no exception".
2. **Hard-delete with a stranger citer:** extend (or add a test alongside) case 5 so a stranger's
   memory in the stranger's team also cites the target; assert `accessible_citers == [own source]`
   and `inaccessible_count == 1`, stranger UUID not in `accessible_citers`.
3. **Opacity:** in the cross-tenant no-access tests (resolve-level case 2 and the SDK E2E case 7),
   also trigger the error with a random `uuid4()` target and assert the two errors are identical
   (resolve: `str(exc)` equal; SDK: same `code` and same `str(exc)` / message / any details the
   exception carries).
4. Fix import ordering / move the inline `PluginValidationError` import to the top so
   `ruff check src tests` is clean.

## Verification — report exact command output summaries
1. `pytest -q -p no:cacheprovider tests/integration/test_references_own_memory_repro.py tests/integration/test_references_access_rule.py tests/unit/test_references_helpers.py tests/integration/test_references_integration.py tests/unit/test_lint_tenant_scope.py tests/unit/test_spec2_slug_lookup.py`
2. Full-suite baseline vs after (this was skipped last time — it is required):
   - `git stash push -u` → `pytest -q -p no:cacheprovider tests 2>&1 | tail -40` → record failing test ids
   - `git stash pop` → confirm `git status` shows all 4 changed/new files again
   - `pytest -q -p no:cacheprovider tests 2>&1 | tail -40` → record failing test ids
   - Report both lists and state explicitly whether any test fails after but not before.
3. `ruff check src tests` and `mypy` — report output (if errors exist, show whether they pre-exist
   on baseline; any errors in files you touched must be fixed).
