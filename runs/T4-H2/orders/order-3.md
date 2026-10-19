# Work order 3 — final cleanups

1. **Layering (`mindmap_get.py`)**: the delta-mode edge query is raw SQL inside the tool. Move it into
   `src/mem_mcp/mindmap/service.py` as e.g. `fetch_edges_touching(conn, *, touched_ids: list[UUID],
   member_ids: list[UUID])` that returns edges where (source OR target) ∈ touched AND both source and target ∈
   member_ids (do the member filter in SQL). Tool stays thin. Keep `lint_tenant_scope` green (memory_references
   is queried the same way `fetch_internal_edges` already does — follow that).

2. **`mindmap_resolve.py` cleanup**:
   - Remove the `if inp.resolved_by_memory_id is not None or True:` hack. Only do the system_tx lookups when a
     resolver is named (no resolver → no edge → no need to resolve the target's team).
   - In the final write `tenant_tx`, re-assert the preconditions before writing, so the check and the write are
     atomic: re-read the map row and require `state == 'live'` (else `map_not_live`), and rely on
     `settle_branch`'s `AND status='open'` guard (else `branch_already_settled`). Optionally lock the map row
     (`SELECT … FOR UPDATE` via a service helper) — `mindmap_close` archiving concurrently must not race a resolve.
   - Remove now-dead comments like "this shouldn't happen" or keep them accurate.

3. **`skills/mindmap-driver/SKILL.md` — still not updated** (asked in orders 1 and 2). Please edit it:
   - Fix the open-loops sentence in "Capture": open loops are open nodes whose `responsible_party` is set
     (`owner` = waiting on the user, `model` = waiting on you); settled branches never appear.
   - Add a section `## Settle a branch` : when a branch is answered or abandoned, call `mindmap_resolve(map_key,
     node_id, resolution_summary="<one line>", disposition="resolved"|"dropped", resolved_by_memory_id=<node that
     settles it, optional>, resolved_by_party="owner"|"model")`. The one-line summary is what later reads show
     instead of the branch. A `resolves-under` link alone does not settle anything. Settling a branch does not
     close the map.
   - Add a section `## Resume cheaply`: every `mindmap_get`/`mindmap_resolve` returns a `cursor`; keep the latest
     one and resume with `mindmap_get(map_key, since=<cursor>)` (returns only what changed; nothing if nothing
     changed). Defaults are `include="open"` (settled branches as one-line entries in `resolved`) and
     `depth="summary"` (long content cut to 200 chars + "…", `truncated=true`); ask for `depth="full"` on a
     node only when you need its full text, `include="all"` only when you need the whole map (e.g. before close).

4. Re-run and report exact counts:
   - `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
   - full `pytest -q -p no:cacheprovider` → counts; confirm the failing set is the same 38 pre-existing failures
     (list any mindmap-related ids in that set, if any).
   - `ruff check src tests`, `ruff format --check src tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_resolve_e2e.py`, `mypy`.
