# Work order 2 — review fixes for mindmap_resolve / cheap reads

Good work overall. Fix the following; keep everything else as is.

1. **Lint/type gates must actually run.** Your report says `ruff`/`mypy` could not be executed. Run them now
   (try `python -m ruff check src tests` and `python -m mypy` if the bare binaries are blocked) and fix every
   finding in files you touched. Known likely issues:
   - `mindmap_resolve.py` imports `BRANCH_STATUS_RESOLVED` but never uses it (F401).
   - Migration 0044 has a SQL string line > 100 cols (`resolution_summary_len` CHECK) — split it.
   - pyproject has `warn_unused_ignores = true`: the `# type: ignore[no-any-return]` comments you added to
     pre-existing code (`service.resolve_map_root`, `service.find_live_map_seeded_from`,
     `_mindmap_common.resolve_team_id`) must be removed again unless mypy *on the baseline tree* didn't report
     those lines and your change made them errors. Don't touch pre-existing code just to silence pre-existing
     mypy errors; report the mypy totals on baseline vs. now instead.

2. **Race between validation and write in `mindmap_resolve`.** Phase 1 validates in one tx, Phase 3 writes in
   another; a concurrent `mindmap_close` (archive) between them would let a branch be settled on an archived map.
   In the Phase-3 write tx, before writing: lock the map row (`SELECT state FROM memory_maps WHERE
   root_memory_id=$1 AND tenant_id=$2 FOR UPDATE` — add a service function, tenant-filtered) and re-check
   `state == 'live'` (→ same `map_not_live` error) and that the node (and resolver, if given) are still members
   of this map (→ same -32602 errors as Phase 1). Make `set_branch_status` return `bool` (whether exactly one
   row was updated, parse asyncpg's `"UPDATE n"` status) and raise the same "not a member" -32602 if False.
   Keep the Phase-1 checks (so failures still abort before the system_tx).

3. **Missing test cases** (add to `tests/integration/test_mindmap_resolve_e2e.py`):
   - `since` after a resolve: take cursor C, resolve n1, then `mindmap_get(since=C)` → `nodes == []`,
     `resolved` contains exactly n1's compact entry; with `include="all"` the same call returns n1 in `nodes`
     with `status` set. Also assert the resolve output `cursor` equals the subsequent `mindmap_get().cursor`.
   - The `resolves-under` / `dropped-under` edge is visible in `mindmap_get(...).edges` (source=resolver,
     target=settled node).
   - Cross-tenant: a second tenant (own UUID-suffixed setup) calling `mindmap_resolve` with the first tenant's
     `map_key`/`node_id` gets -32602 and nothing changes.
   - Content of exactly 200 chars via the tool → unchanged, `truncated=False`.

4. Re-run: `alembic upgrade head`; `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_unit.py
   tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py
   tests/unit/test_lint_tenant_scope.py`; then the full `pytest -q -p no:cacheprovider` and report the exact
   counts (previous: 38 failed / 1266 passed / 15 errors — confirm the failing set is unchanged and contains no
   mindmap test). Report exact ruff and mypy output summaries.
