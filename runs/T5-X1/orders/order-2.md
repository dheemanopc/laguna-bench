# Work order 2 — Tighten tests + provide verification evidence

The implementation in `update.py` / `get.py` / `versioning.py` looks right. Please make the following changes. Do not change the design.

## Source nits (`src/mem_mcp/mcp/tools/update.py`)
1. In the in-place content branch you moved `content_hash = hash_content(inp.content)` inside the `else:` of the embed block, where it is now a dead assignment (the UPDATE calls `hash_content(...)` inline). Remove the dead assignment / restore one clean `content_hash = hash_content(inp.content)` before the UPDATE and pass `content_hash`. Keep behaviour identical.
2. `_find_current_version`: add `ORDER BY version DESC NULLS LAST` (pick highest version if several) before `LIMIT 1`, and fold the second query into the first (select `id, updated_at` directly) so it's one round-trip. Keep it walking forward via `superseded_by` (that's fine).

## Test changes (`tests/integration/test_update_concurrency.py`)
3. **Use a dedicated larger pool for the concurrent calls.** The `pg_pool` fixture has only 4 connections, so 10 "concurrent" calls are mostly queued on the client side. Add a fixture (module-level, async) that creates `asyncpg.create_pool(<same DSN/init as the pg_pool fixture uses — look at tests/conftest.py / tests/integration/conftest.py for how it's built, including any `init=` codec setup>, min_size=12, max_size=12)` and use it as `db_pool` for every `MemoryUpdateTool` call in the concurrency tests (setup/cleanup can keep using `pg_pool`). Before closing that pool, let memory_get's background access bump drain (e.g. `await asyncio.sleep(0.2)` and/or await any pending tasks from `mem_mcp.memory.access_tracking` if it keeps a task set), then `await pool.close()`.
4. Use **10** concurrent callers in the versioned-fork test and the expected_revision test (not 5).
5. Versioned fork test: additionally assert every conflict has `data["current_id"] == str(winner.id)` and that the winner's `version == 2`.
6. Same-valid-expected_revision test: after the gather, fetch `memory_get` revision and assert every conflict's `data["current_revision"]` equals it, and that it equals the winner's `revision`. Fix the misleading comment ("Verify memory unchanged").
7. `test_noop_update_changes_revision`: actually capture the revision **before** the no-op update (via memory_get) and assert `output.revision != before`, plus the existing equality with memory_get after.
8. Add a test: concurrent mixed operations on a current `decision` — 1 content update + 5 `tags_op="add"` calls gathered together. Assert: exactly one current row in the chain afterwards; every call either succeeded or raised -32000 `update_conflict`; every tag-add that *succeeded* has its tag present on the final current row (tags from in-place updates applied before the version bump are carried to v2 by the versioned path, those after it are refused). This guards that no successful write is silently lost.
9. Add a test: concurrent in-place content updates to a `note` (10 callers, distinct contents, no expected_revision) all succeed and the final content is one of the submitted contents (last-writer-wins), and the final revision equals the revision of exactly one of the successful outputs (the last writer's).

## Verification evidence (required — report exact commands + summary lines)
a. `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_update_revision.py tests/integration/test_update_concurrency.py`
b. Run `tests/integration/test_update_concurrency.py` 5 times in a row; report each result line.
c. **Prove the tests catch the bug**: `git stash push -- src/` , run `pytest -q -p no:cacheprovider tests/integration/test_update_concurrency.py` and report which tests fail and why (in particular the concurrent tag-add and the versioned-fork tests must fail against the old code — tests referencing `expected_revision`/`revision` will fail for trivially missing fields, that's fine). Then `git stash pop` and confirm `git status` shows your src changes restored.
d. Full suite: `pytest -q -p no:cacheprovider` with src stashed (baseline) and with your changes; list the failing test node ids in both runs and confirm the "after" set is a subset of the "before" set (except none of yours fail). If the baseline run is too flaky to compare, say so with details.
e. `ruff check src tests` and `mypy` — report output (at least for touched files).
