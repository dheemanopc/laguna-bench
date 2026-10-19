# Work order 2 — review fixes for mindmap_resolve / mindmap_get

Good work on order 1. Please make these focused fixes:

1. **Edge written through the same path as `mindmap_link`** (`src/mem_mcp/mcp/tools/mindmap_resolve.py`):
   `mindmap_link` calls `resolve_reference_target(sys_conn, target_uuid=<edge target>, ...)` and passes the
   resolved `memory_id`/`team_id` to `insert_reference`. In resolve, the edge target is the **settled node**
   (`node_id`), so when a resolver is named, resolve the target `node_id` the same way and use its returned
   `team_id` as `target_team_id` (instead of the map's team). Keep the existing accessibility check of
   `resolved_by_memory_id` too (it is the edge source; an inaccessible/nonexistent resolver must produce the opaque
   `-32602 memory_not_accessible`, never a raw FK error). Note: do the membership check (node in this map) before
   any error that could reveal anything about `node_id` — i.e. a node that's not in this map must yield the
   `-32602` `path: node_id` error, not `memory_not_accessible`. Simplest: move both system_tx lookups after the
   tenant-side checks, or perform the map/membership checks first in their own read and keep the authoritative
   checks + writes in the single write transaction. Status update + edge + event must still be one `tenant_tx`.

2. **`mindmap_get` edges when `since` is set**: return edges among map members where the source OR target is a
   touched member (both endpoints must still be map members). Currently both endpoints must be in the returned
   set, which hides e.g. a new challenge's edge to an older, unchanged position. When `since is None`, behaviour
   unchanged (edges among all map members).

3. **`service.current_cursor`**: add `tenant_id` param and `AND tenant_id = $2` (defence in depth, CONVENTIONS).

4. **`service.settle_branch`**: annotate return as `dict[str, Any] | None`, drop the `type: ignore`.
   Revert the unrelated `UUID(str(val))` changes to `resolve_map_root` / `find_live_map_seeded_from` unless they
   were needed for a failing test/mypy — if needed, tell me why. Simplify `fetch_touched_since` to
   `{r["memory_id"] for r in rows}` if that works (asyncpg UUIDs hash/compare equal to `uuid.UUID`); keep it if
   not, and say why.

5. **Tool description `mindmap_resolve`**: `resolution_summary` is REQUIRED (≤500 chars), not optional; it is the
   one line that every later cheap `mindmap_get` shows (in the `resolved` list) instead of the branch. Fix the
   "Behavior" paragraph (it currently says the summary replaces content under depth="summary", which is wrong —
   it's include="open" that moves settled branches into `resolved`). Mention disposition values, resolved_by_party
   default model, and the edge kinds (`resolves-under` / `dropped-under`, resolver → settled node).
   Also mention in the `mindmap_get` description that `since` returns nothing (and the same cursor) when nothing
   changed, and that a resolve/write advances the cursor.

6. **`skills/mindmap-driver/SKILL.md`** was not updated (order 1, section D last bullet). Add a short
   "Settle a branch" section (`mindmap_resolve` with a one-line `resolution_summary`, optional
   `resolved_by_memory_id`, `disposition="dropped"` for abandoned branches; an edge alone never settles a branch)
   and in resume guidance: keep the last `cursor`, resume with `mindmap_get(map_key, since=<cursor>)`, request
   `include="all"` / `depth="full"` only when needed. Also fix the sentence about open loops to match
   the open_loops definition (open nodes with responsible_party owner or model).

7. Add/adjust tests in YOUR new test files only for: (a) `since` edge visibility (new node linked to an old
   unchanged node → edge returned on `get(since=c)`), (b) resolve with a node from a *different* map plus a valid
   resolver → `-32602` with `path: node_id` and nothing written (no edge, no event, status unchanged),
   (c) nonexistent `resolved_by_memory_id` (random uuid) → `-32602 memory_not_accessible`, node still open.

## Verification — report exact output summaries
- `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py`
- Full suite `pytest -q -p no:cacheprovider`: give the pass/fail/skip counts and the **list of failing test ids**,
  and for each failure state whether it fails identically on the baseline (`git stash -u`, run just those
  failing tests, `git stash pop`; the DB stays at new head — fine). I need explicit confirmation that
  `tests/integration/test_mindmap_e2e.py` and every other existing test passes or was already failing on baseline.
- `ruff check src tests`, `ruff format --check` on touched files, `mypy` (report output for touched files).
