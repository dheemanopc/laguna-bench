# Work order 2 — review fixes for branch status / mindmap_resolve

Good work on order 1. Your final report was cut off, so I did not see the verification results. Please
apply these fixes, then re-run and report verification exactly.

## Fixes
1. **`skills/mindmap-driver/SKILL.md`**: there is a stray duplicated `## Review` heading directly above
   `## Settle a branch` — remove the stray one. Also add one sentence to that section: on resume call
   `mindmap_get(map_key=..., since=<cursor from your last read/resolve>)` to fetch only what changed;
   use `include="all"` / `depth="full"` only when you need the whole map.
2. **`src/mem_mcp/mindmap/__init__.py`**: the comment above `SUMMARY_CONTENT_CHARS` is wrong — it says it
   is the max length of the resolution summary matching the migration CHECK. It is actually the
   `mindmap_get(depth="summary")` content-truncation length. Fix the comment, and add a separate
   `RESOLUTION_SUMMARY_MAX_CHARS: Final[int] = 500` (comment: matches the migration CHECK) and use it for
   `max_length` of `MindmapResolveInput.resolution_summary`.
3. **Race on map lifecycle in `mindmap_resolve`**: in the write transaction, the "map is live" re-check
   does not lock, so a concurrent `mindmap_close` can archive the map between check and update. Add a
   service function e.g. `lock_map_row(conn, *, root_memory_id, tenant_id) -> dict | None` doing
   `SELECT ... FROM memory_maps WHERE root_memory_id = $1 AND tenant_id = $2 FOR UPDATE` and use it for
   the state re-check in the write tx (keeps the `map_not_live` error).
4. **`service.touched_member_ids_since` docstring** says map-level events (open/close/review) have NULL
   memory_id — `open` actually logs the root id. Correct the docstring (behaviour is fine).
5. Make sure the `since` `Field(...)` line in `MindmapGetInput` and any other new lines are ruff-format
   compliant (~100 cols); run `ruff format` on the files you created/changed in `src/` and `tests/`
   (only those files) and `ruff check src tests`.

## Verification — report exact command lines and results
1. `alembic upgrade head` (state the current head revision).
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_cheap_reads.py tests/integration/test_mindmap_resolve.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
3. Full suite `pytest -q -p no:cacheprovider` — give pass/fail/skip/error counts and list every failing
   test id. For each failure, state whether it is pre-existing (it must also fail without your changes —
   verify with `git stash -u`, rerun just those failing tests, `git stash pop`, and confirm `git status`
   shows all your files back) or caused by you (then fix it).
4. `ruff check src tests` and `mypy` — paste the summary lines; any errors in files you touched must be fixed.
Keep the report concise (under ~60 lines) so it is not truncated.
