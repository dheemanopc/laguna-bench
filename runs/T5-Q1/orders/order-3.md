# Work order 3 — final fixes

Good progress. Remaining items:

## Code
1. `src/mem_mcp/mcp/tools/update.py`, versioned path: the `if isinstance(updated, str) and updated.split()[-1] == "0":`
   branch references `current`, which is only defined inside the earlier superseded-check branch → `NameError`
   (UnboundLocalError) if that branch is ever hit. Call `resolve_current(conn, target["id"], ctx.tenant_id)` inside
   this branch to build `current_id` (same data shape as the main superseded conflict). Ideally factor the
   superseded-conflict construction into one small private helper `_superseded_conflict(conn, target, tenant_id)`
   that returns the `JsonRpcError`, used in both places.

## Tests (`tests/integration/test_memory_update_concurrency.py`)
2. The concurrency tests use the shared `pg_pool` fixture (max 4 connections), so at most 4 updates truly run in
   parallel. Add a module-level fixture `big_pool` that creates its own pool exactly like `pg_pool` in
   `tests/conftest.py` (same DSN env, skip if unset, `init=_init_connection` from `mem_mcp.db.pool`) but with
   `max_size=16`, and use it in all concurrency tests (1, 2, 3, 6) for the update calls. Close it in the fixture
   teardown after draining bumps.
3. Replace the `asyncio.sleep(0.5)` in `_drain_bumps` with a real drain: `mem_mcp.memory.access_tracking._inflight_tasks`
   — `await asyncio.gather(*list(_inflight_tasks), return_exceptions=True)` (keep a tiny sleep only if needed).
4. Test 6 (`TestConcurrentExpectedRevision`): additionally assert every refused error's `current_revision ==
   successes[0].revision`, and that the DB row's content equals the winner's content and its revision equals the
   winner's returned revision.
5. Test 3: also assert the winner's `revision` equals `memory_get(winner.id).memory.revision`.

## Prove tests catch the bug (git stash was not available to you)
6. Do it without stash: `cp src/mem_mcp/mcp/tools/update.py /tmp/update_fixed.py && git show HEAD:src/mem_mcp/mcp/tools/update.py > src/mem_mcp/mcp/tools/update.py`
   (if `/tmp` is not writable, use a path under the repo's parent that is git-ignored or simply another filename
   outside `src/`), then run `pytest -q -p no:cacheprovider tests/integration/test_memory_update_concurrency.py -k "TagsAdd or DecisionFork or ConcurrentExpectedRevision"`
   and record the outcome (they should fail — some may fail for the missing `revision`/`expected_revision` field,
   that's fine; TagsAdd and DecisionFork should fail on the assertions about lost tags / multiple successes).
   Then restore: `cp /tmp/update_fixed.py src/mem_mcp/mcp/tools/update.py` and `git diff --stat` to confirm restored.
   If you cannot run any of this, say so plainly.

## Verify & report exact results
- `pytest -q -p no:cacheprovider tests/unit/test_tools_update.py tests/unit/test_memory_record_revision.py tests/integration/test_memory_update_concurrency.py`
  (concurrency file 3×).
- Full suite `pytest -q -p no:cacheprovider` → give the count and list of failing test node ids. For the baseline,
  if you cannot stash, compare against: run the full failing list and for each failure confirm it is unrelated to
  memories/update/get (grep the failure message) — list any failure that touches `memory_get`, `memory_update`,
  `MemoryRecord`, `memories` columns, or `revision`.
- `ruff check src tests`, `ruff format --check` on changed/new files, `mypy`.
