# Work order 2 — Fixes after review of order 1

The core design in `update.py` / `get.py` / `get_batch.py` / `write.py` / migration 0046 is good; keep it.
Fix the following.

1. **Revert the edit to the existing test `tests/unit/test_web_memories_handler.py`.** Existing tests must not be
   modified. Restore that file exactly to its original content (remove the `revision="test-revision",` line you
   added). Make it pass anyway by giving `MemoryUpdateOutput.revision` a default: `revision: str = ""`. The tool
   always sets it, so the default only keeps old constructors (web/plugin code, tests) working. Grep `src/` for
   other `MemoryUpdateOutput(` constructions and for code that serializes or forwards it (web handler, plugin
   SDK `MemoryClient.update`), and confirm they still work. Do not change the `MemoryClient.update` signature.

2. **Remove the session-scoped autouse `_apply_migrations` fixture** from
   `tests/integration/test_memory_update_concurrency.py`. Tests must not run migrations; the harness runs
   `alembic upgrade head` beforehand. Also drop the now-unused imports.

3. **Use a dedicated, larger pool for the concurrency tests.** The default `pg_pool` fixture has only 4
   connections, so 5 gathered calls partly serialize on pool checkout and the race is weak. Add a module-level
   async fixture (e.g. `wide_pool`) that creates an asyncpg pool from `MEM_MCP_TEST_DSN` with `min_size=12,
   max_size=12`, configured exactly like the `pg_pool` fixture in `tests/conftest.py` (same `init`/codec setup,
   reuse its helper if there is one). It skips when the DSN is unset, and before `pool.close()` it waits for
   outstanding background `bump_access` tasks to drain (look at how `bump_access` schedules its work, and await
   or sleep briefly as appropriate). Use it in every test that runs `asyncio.gather`, and raise the concurrency to
   **8** callers in those tests (tags add/remove, versioned 1-winner, in-place token 1-winner, in-place LWW). Keep
   the assertions strict: exactly 1 winner, and N−1 conflicts with `data["code"] == "update_conflict"`, code
   -32000, and `current_id` (versioned) / `current_revision` (token) equal to the winner's id / revision. For the
   versioned case, also assert in SQL that the chain has exactly one `is_current` row and exactly one row with
   `supersedes = original_id`.

4. **Prove the tests catch the bug.** Temporarily remove `FOR UPDATE` from the lookup in `update.py` **and** the
   `AND is_current AND superseded_by IS NULL` guard (and the `UPDATE 0` branch), run
   `python -m pytest tests/integration/test_memory_update_concurrency.py -q -p no:cacheprovider`, and record which
   tests fail. Then restore the code exactly. Report the failing test names and the restored-run result. If the
   tag tests don't fail reliably without the lock, make the race wider (e.g. a stub embedder or quota that awaits
   `asyncio.sleep(0.05)` on the in-place path won't help for tags-only; instead add a small `asyncio.sleep` hook
   only in the test, or increase N). Do not add sleeps to production code.

5. **Run the tooling you said you couldn't.** Try `python -m ruff check src tests`, `python -m mypy` (with the
   pyproject config), and `python -m alembic downgrade -1 && python -m alembic upgrade head` (or the equivalent
   `python -m alembic ...` invocations). If something is genuinely unavailable, say exactly what command you tried
   and its error output. Fix any ruff/mypy issues in files you touched.

6. **Full-suite comparison.** Run `python -m pytest -q -p no:cacheprovider` and list the failing test ids. To get
   the baseline, list which failing tests touch code you changed. For any failure in `tests/unit/test_tools_update*`,
   `test_web_memories_handler`, `get`/`get_batch`/`write`, or the plugin client tests, investigate and confirm
   whether it is pre-existing: e.g. check that the failure has nothing to do with revision/update, or temporarily
   revert your src changes and re-run that one test.

Report: exact commands and results for each item above.
