# Work order 2 — review fixes for order 1 (same feature)

Your previous session ran out of time before reporting. The implementation is broadly right; apply these
fixes, then VERIFY and REPORT. Budget your time: do the fixes first (they're small), then run the checks
below, and keep the final report short. Don't rewrite things that aren't listed.

## Fixes

1. **`mindmap_resolve` already-settled error** (`src/mem_mcp/mcp/tools/mindmap_resolve.py`): the pre-check
   currently folds "member exists but status != open" into the "node is not a member of this map" error.
   Split it: `member is None` → the existing not-a-member error (path `node_id`); member present but
   `status != "open"` → `JsonRpcError(-32602, "branch already settled", data={"code": "branch_already_settled"})`.
   Keep the root check (`node_role == "root"`) before the already-settled check.
2. **Layering**: the raw `SELECT state FROM memory_maps WHERE root_memory_id = $1 FOR UPDATE` in the tool
   must move to `mindmap/service.py` (e.g. `lock_map_state(conn, *, root_memory_id, tenant_id) -> str | None`,
   with an explicit `AND tenant_id = $2` filter). Tools contain no SQL.
3. **Domain exceptions**: `NodeNotInMapError` / `BranchAlreadySettledError` are defined but unused. Either use
   them (e.g. `settle_branch` raises `BranchAlreadySettledError` when the UPDATE returns no row, and the tool
   maps it with `raise JsonRpcError(...) from e`) or delete them. Prefer using `BranchAlreadySettledError` that
   way; delete `NodeNotInMapError` if it stays unused.
4. Typo `_Disposion` → `_Disposition`. Merge `from mem_mcp.mindmap import DISPOSITION_EDGE_KIND` and
   `from mem_mcp.mindmap import service` into one import. Remove the pointless
   `_ = resolved_target["memory_id"]` line. The two separate `system_tx` blocks can be one.
5. **`main.py` import order**: `mindmap_resolve` import must be sorted alphabetically (after
   `mindmap_open`/`mindmap_review`? — follow ruff's isort: `..._close, _get, _link, _open, _resolve, _review,
   _write_node`). Keep `MindmapResolveTool` in the tool list grouped with the mindmap tools.
6. **`mindmap_get` delta ordering**: with `since`, candidates are built by iterating a `set` → nondeterministic
   order. Build them by filtering the `members` list (already ordered by `added_at`):
   `candidates = [m for m in members if m["memory_id"] in touched]`.
7. **`mindmap_get` duplication**: factor the `MindmapNode(...)` construction into one small helper used by
   both include modes.
8. **`mindmap_get` description not updated**: `TOOL_DESCRIPTIONS["mindmap_get"]` in
   `src/mem_mcp/mcp/tool_descriptions.py` is unchanged. Rewrite it in house style to cover: default cheap
   behaviour (open branches only, content cut to 200 chars + "…" with `truncated=true`), `resolved` compact
   list, `include="all"`, `depth="full"`, the `cursor` → `since=<cursor>` resume workflow (no change → no nodes),
   `open_loops` = open nodes whose turn is someone's (`responsible_party` owner|model), settled branches are
   never open loops. Keep a "Call when / Do not call for / Example" structure.
9. **Formatting**: several new lines exceed 100 cols (the `Field(... description=...)` lines in
   `mindmap_get.py`, the self-resolution error in `mindmap_resolve.py`, migration lines that ruff format
   would join). Run `ruff format` on ONLY the files you created/modified in this feature
   (migration 0044, mindmap_get.py, mindmap_resolve.py, mindmap/__init__.py, mindmap/service.py, main.py only
   if format doesn't churn unrelated lines — if it does, fix by hand instead; tool_descriptions.py likewise;
   your two test files).

## Verification (report exact commands + pass/fail counts)
1. `alembic upgrade head` (state the current head after).
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_branch_status.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
   — all must pass. Make sure there is a test asserting `branch_already_settled` code on a second resolve.
3. `pytest -q -p no:cacheprovider -x --timeout ...` is NOT needed; run the full suite once:
   `pytest -q -p no:cacheprovider 2>&1 | tail -40` and list every failure. For each failure state whether it
   touches mindmap/your files; for any that might, re-run it on the baseline (`git stash -u`, run that test
   only, `git stash pop`) — be careful to restore your work afterwards, and check `git status` after.
4. `ruff check src tests` and `mypy` (report any errors in files you touched; ignore pre-existing elsewhere,
   but say how many).
Do not commit. Report: files changed, commands + results, open issues.
