# ORDER dev1-5 — last small fixes (same lane: `src/mem_mcp/mindmap/work_items.py`, `tests/unit/test_work_items_service.py`)

Reviewed: targeted tests pass; full suite shows only environment/shared-DB failures. Remaining defects, found by reading/grepping:

1. `ruff check src tests` FAILS: `work_items.py` ~line 1095 unused `actual_map_key` (F841). Remove it. Also run `ruff format src/mem_mcp/mindmap/work_items.py tests/unit/test_work_items_service.py` (line ~324 `_check_permission` exceeds 100 cols) and re-run `ruff check src tests` → must print "All checks passed!".
2. `mark_work_item` (line ~465) still calls `_validate_kind(kind)` BEFORE the map/permission checks. Move it after `_check_permission` (a viewer sending a bad kind must get the permission error; a stranger "map not found"). Add a unit test for both.
3. `mark_work_item`: no `asyncpg.UniqueViolationError` handling around the `INSERT INTO work_items` (race between two concurrent marks). Wrap the insert: on UniqueViolationError raise `AlreadyWorkItemError`. Because a failed statement aborts the transaction in Postgres, wrap the INSERT in `async with conn.transaction():` (savepoint) so the caller's tx stays usable. Add a unit test that triggers it (e.g. insert the row via raw SQL right before calling the INSERT path is hard — acceptable alternative: monkeypatch the pre-check query helper to return None so the INSERT hits the unique violation; assert `AlreadyWorkItemError` and history count unchanged).
4. `_check_permission` silently passes when `get_team_role` returns None (`caller_role is not None and …`). It is only called after `_load_map`, but make it safe: None → `WorkItemMapNotFoundError`.
5. `mark_work_item` bypasses `_record_change` (calls `service.log_event` directly, 8 lines) — use the helper like the others.
6. `alembic heads` currently shows `0047_work_item_history_rls_fix (head)` as a no-op migration; leave it (deletion is denied) — nothing to do.

Verify and quote: `ruff check src tests`, `ruff format --check` on your two files, `mypy`, `pytest tests/unit/test_work_items_service.py tests/integration/test_mindmap_work_items_e2e.py tests/unit/test_lint_tenant_scope.py -q`. Do not touch other files. Report briefly.
