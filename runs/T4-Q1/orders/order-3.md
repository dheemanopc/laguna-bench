# Work order 3 — revert out-of-scope change, finish the order-2 items that were skipped

Please work through EVERY numbered item below and tick each one off in your report (item number → what you did).

## 1. Revert `src/mem_mcp/mcp/tools/write.py` completely
`git checkout -- src/mem_mcp/mcp/tools/write.py`. Changing the core memory_write encoding is out of scope for
this task and changes how every memory's metadata is stored. (You correctly found that `memory_write` stores
metadata double-encoded as a JSONB *string* because the pool's jsonb codec also runs `json.dumps`; existing rows
in production are stored that way too, so our code must tolerate it rather than rely on a fix.)

Consequence: do NOT filter on `m.metadata->>'responsible_party'` in SQL. Rewrite `service.fetch_open_loop_ids` to
select `mm.memory_id, m.metadata` for the map's members with `mm.status = 'open'`, `mm.tenant_id = $2`,
`m.tenant_id = $2`, `m.deleted_at IS NULL`, ordered by `mm.added_at`, and filter in Python with
`_as_dict(metadata).get("responsible_party") in ("owner", "model")` (put the tuple as a constant in
`mindmap/__init__.py`, e.g. `RESPONSIBLE_PARTIES`). All tests must pass with write.py reverted.

## 2. Delete the debugging test files
`tests/integration/test_debug_open_loops.py`, `tests/integration/test_jsonb_cast.py`,
`tests/integration/test_jsonb_minimal.py`. If `rm` is blocked use `git clean -f <path>` or
`python -c "import os; os.remove('<path>')"`. Confirm with `git status --short` in your report.

## 3. `set_branch_status`: explicit tenant filter + live-map guard, return the outcome
Signature gains `tenant_id: UUID`. SQL:
```sql
UPDATE memory_map_membership mm
   SET status = $4, resolution_summary = $5, resolved_by_memory_id = $6,
       resolved_by_party = $7, resolved_at = now()
 WHERE mm.memory_id = $1 AND mm.root_memory_id = $2 AND mm.tenant_id = $3
   AND mm.node_role <> 'root'
RETURNING mm.memory_id
```
Return `bool` (row updated). In the tool's write transaction, BEFORE the update, lock and re-check the map:
new service fn `lock_live_map(conn, *, root_memory_id, tenant_id) -> bool` doing
`SELECT state FROM memory_maps WHERE root_memory_id = $1 AND tenant_id = $2 FOR UPDATE` and returning
`state == 'live'`; not live → raise the same `map_not_live` JsonRpcError (inside the tx, so it rolls back). If
`set_branch_status` returns False → raise the same -32602 `node_id` error. Remove `lock_membership` (the map lock
+ the conditional UPDATE replace it). `mindmap_close` archives via UPDATE on the same `memory_maps` row, so the
FOR UPDATE lock serialises resolve vs close.

## 4. `fetch_node_team_id` needs `AND tenant_id = $2` (signature gains `tenant_id`). Call it inside the
write transaction (not the read-only one).

## 5. `deleted_at` / tenant filters on member queries
Every member query in `fetch_members_cursor` and `fetch_settled_members` must include
`AND m.tenant_id = <tenant param> AND m.deleted_at IS NULL` (join `memories m` in `fetch_settled_members` too),
matching `fetch_members`.

## 6. Compute the since-window once per request
Replace `fetch_members_cursor` + `fetch_settled_members` with ONE service function, e.g.
`fetch_window_members(conn, *, root_memory_id, tenant_id, since) -> list[dict]`, returning every (non-deleted)
member in the window (all members when `since is None`; members in `fetch_touched_member_ids(...)` when `since` is
set; `[]` if nothing touched) with columns `memory_id, node_role, added_at, status, resolution_summary,
resolved_by_party, content, type, metadata, created_at`, ordered by `added_at`. The tool then splits:
- `include="all"` → all rows to `nodes`, `resolved = []`.
- `include="open"` → `status == 'open'` rows to `nodes`, the others to `resolved` (compact entries).
Delete the old two functions. `fetch_touched_member_ids` then needs only the `since is not None` branch
(drop the unused `since=None` branch and the unused `tenant_id` param, or use it).

## 7. Edges: at least one endpoint in the returned set
New service fn `fetch_edges_touching(conn, *, member_ids, touched_ids)`:
```sql
SELECT source_memory_id, target_memory_id, reference_kind, created_at
FROM memory_references
WHERE source_memory_id = ANY($1::uuid[]) AND target_memory_id = ANY($1::uuid[])
  AND (source_memory_id = ANY($2::uuid[]) OR target_memory_id = ANY($2::uuid[]))
ORDER BY created_at ASC
```
`member_ids` = ALL current members of the map (cheap id-only query, e.g. new `fetch_member_ids` with tenant +
deleted_at filters); `touched_ids` = ids in `nodes` ∪ `resolved`. Empty returned set → `edges = []` without a
query. With `since=None` + `include="all"` this equals the old full internal-edge set.

## 8. Migration constraint names
Rename constraints to the table-prefixed form: `memory_map_membership_resolution_summary_check`,
`memory_map_membership_resolved_by_party_check`, `memory_map_membership_status_consistency_check`
(status check already prefixed). Update downgrade. Then `alembic downgrade -1 && alembic upgrade head`.

## 9. Tests (your new test files only; existing tests untouched)
Make sure these exist and pass (add if missing):
- (a) `since=<cursor>` after writing a NEW node that `links` to an OLDER node (use `mindmap_write_node` with
  `links=[...]`, or a `mindmap_link`): `nodes` contains only the new node (plus the link target if the link was
  logged as a map event), `edges` contains the new→old edge, and `open_loops` still contains an OLDER open node
  that has `responsible_party="owner"`.
- (b) `include="all"`, no `since`: `edges` set equals all internal edges of the map.
- (c) A node written with `responsible_party="model"` is in `open_loops`; a node without responsible_party is not;
  after `mindmap_resolve` the node is no longer in `open_loops`.
- (d) Soft-deleted member (set `deleted_at = now()` via a direct UPDATE in the test) does not appear in
  `nodes`, `resolved`, or `open_loops`.

## 10. Verification (paste exact outputs/counts in the report)
- `alembic downgrade -1 && alembic upgrade head`
- `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_get_models.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py`
- `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py`
- Full suite AFTER: `pytest -q -p no:cacheprovider 2>&1 | tail -60` → list of FAILED/ERROR ids.
- Full suite BEFORE (baseline): `git stash -u` ; `alembic downgrade 0043_backfill_personal_teams` ;
  `pytest -q -p no:cacheprovider 2>&1 | tail -60` ; `git stash pop` ; `alembic upgrade head`.
  (If downgrade fails while stashed because 0044 file is gone, run the downgrade BEFORE stashing.)
  Report both FAILED/ERROR lists and state explicitly whether AFTER ⊆ BEFORE.
- `ruff check src tests alembic/versions/0044*` and `ruff format --check` on all changed/new files; `mypy`
  (report any errors in changed files).
