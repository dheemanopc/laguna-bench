# Work order 4 — finish order 3 items 2, 9, 10 (cleanup, tests, verification)

The code changes from order 3 (items 1, 3–8) look right; do not restructure them. Your shell was unavailable last
time — please retry it now (start with a trivial `git status --short`). If the shell is still unavailable, say so
in the first line of your report and stop. Do not guess results.

1. Small fix: in `service.fetch_open_loop_ids`, move `from mem_mcp.mindmap import RESPONSIBLE_PARTIES` to a
   top-of-module import (no cycle: `mindmap/__init__.py` does not import `service`).
2. Delete `tests/integration/test_debug_open_loops.py`, `tests/integration/test_jsonb_cast.py`,
   `tests/integration/test_jsonb_minimal.py` (`git clean -f <path>` or `python -c "import os; os.remove(...)"`
   if `rm` is blocked). Show `git status --short` afterwards.
3. Tests, item 9 of order-3 (in `tests/integration/test_mindmap_resolve_e2e.py`, add any missing):
   - (a) `since=<cursor>` after writing a NEW node with `links=[{target_memory_id: <older node>, reference_kind:
     "displaced-from"}]`: `nodes` contains the new node; `edges` contains the new→older edge; `open_loops` still
     contains an OLDER open node that has `responsible_party="owner"`.
   - (b) `include="all"`, no `since`: the set of `(source, target, kind)` in `edges` equals all internal edges
     (query `memory_references` directly for both endpoints in the map's membership and compare).
   - (c) `responsible_party="model"` node is in `open_loops`; a node without responsible_party is not; after
     `mindmap_resolve` the node is no longer in `open_loops`.
   - (d) soft-deleted member (direct `UPDATE memories SET deleted_at = now() WHERE id = $1` through a
     `system_tx`/pool connection) is absent from `nodes`, `resolved` and `open_loops`.
   - (e) resolve with `resolved_by_memory_id` that does not exist → -32602 `memory_not_accessible`, membership
     still `open`, no edge, no new event (cursor unchanged).
   Check that your existing tests still match the current code (e.g. anything referring to removed service
   functions `fetch_members_cursor`, `fetch_settled_members`, `lock_membership`).
4. Verification — paste exact results:
   - `alembic downgrade -1 && alembic upgrade head`
   - `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_get_models.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
   - Full suite after: `pytest -q -p no:cacheprovider 2>&1 | grep -E "^(FAILED|ERROR)|passed|failed"`.
   - Baseline: run `alembic downgrade 0043_backfill_personal_teams` FIRST, then `git stash -u`, run the same full
     suite command, then `git stash pop`, then `alembic upgrade head`. Report both FAILED/ERROR lists and state
     whether AFTER ⊆ BEFORE. (Make sure `git stash pop` succeeded — show `git status --short` after.)
   - `ruff check src tests alembic/versions/0044*`, `ruff format --check` on every changed/new file, and `mypy`
     (report errors in changed files, if any).
