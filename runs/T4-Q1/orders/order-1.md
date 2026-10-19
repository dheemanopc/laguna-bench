# Work order 1 — Mind-map branch status, `mindmap_resolve`, open_loops fix, cheap reads on `mindmap_get`

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md`, `src/mem_mcp/mindmap/service.py`,
`src/mem_mcp/mindmap/__init__.py`, all `src/mem_mcp/mcp/tools/mindmap_*.py`, `_mindmap_common.py`,
`src/mem_mcp/teams/references.py`, `alembic/versions/0038_2026_06_19_mindmap_tables.py`,
`tests/integration/test_mindmap_e2e.py`.

## Problem
`mindmap_get` returns every node in full every time, so cost grows with total discussion. There is no
per-branch status (only `mindmap_close` settles the whole map), so `open_loops` only grows.

## A. Stored branch status — new Alembic migration
New file `alembic/versions/0044_2026_10_16_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`, docstring explaining *why* (as peers do), SQL via
`op.execute(sa.text(...))`, real `downgrade()`.

Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open'` with `CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` with CHECK length between 1 and 500 when not null
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL` with `CHECK (resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: when `status='open'` then summary/party/resolved_at/resolved_by_memory_id are all NULL;
  when status is `resolved`/`dropped` then `resolution_summary`, `resolved_by_party`, `resolved_at` are NOT NULL.
- Index `memory_map_events (root_memory_id, id)` to serve cursor reads.
Name all constraints explicitly so downgrade can drop them. Existing rows default to `open`.
Run `alembic upgrade head` (and verify downgrade -1 / upgrade head round-trips).

Status is the ONLY source of truth for "settled". Never infer it from `memory_references.reference_kind`;
an edge alone (e.g. a `mindmap_link` with `resolves-under`) never settles a branch.

## B. New tool `mindmap_resolve`
Module `src/mem_mcp/mcp/tools/mindmap_resolve.py`, classes `MindmapResolveTool` (name `mindmap_resolve`,
`required_scope = "memory.write"`), `MindmapResolveInput`, `MindmapResolveOutput`. Register in
`src/mem_mcp/main.py` with the other mindmap tools; add a description to `mcp/tool_descriptions.py` in the
house style (what it does, "Call when: …", "Do not call for: …", example).

Input (`model_config = ConfigDict(extra="forbid")` is fine but keep consistent with other mindmap inputs):
- `map_key: str = Field(..., min_length=1, max_length=64)`
- `node_id: UUID`
- `disposition: Literal["resolved","dropped"] = "resolved"`
- `resolution_summary: str = Field(..., min_length=1, max_length=500)` (required)
- `resolved_by_memory_id: UUID | None = None`
- `resolved_by_party: Literal["owner","model"] = "model"`
- `team_id: UUID | None = None`

Output: `node_id`, `status` (new status), `resolution_summary`, `cursor: int`, `request_id`.

Behaviour:
1. Resolve team + map root exactly like the other mindmap tools. Unknown map → `JsonRpcError(-32602,
   "map not found", data={"errors":[{"path":"map_key"}]})`.
2. Map must be live: archived → `JsonRpcError(-32602, ..., data={"code":"map_not_live"})` (no-reopen rule,
   same as write_node/close). Nothing changes.
3. `node_id` must be a member of THIS map (membership row with `root_memory_id = this root` and
   `tenant_id = caller tenant`). A node of another map, a non-member, or an unknown id → `-32602` with
   `data={"errors":[{"path":"node_id", "message": ...}]}`, same response for all those cases (opaque), nothing
   changed. The root node itself (node_role `root`) cannot be resolved → same -32602 on `node_id`
   (settling the whole map is `mindmap_close`'s job).
4. If `resolved_by_memory_id` is given: it must differ from `node_id` (else -32602 path
   `resolved_by_memory_id`), and must be readable by the caller — validate it with
   `resolve_reference_target(sys_conn, target_uuid=..., caller_user_id=ctx.tenant_id)` inside `system_tx`
   exactly as `mindmap_link` does; on `ReferenceTargetNotFoundError` raise
   `JsonRpcError(-32602, "reference target not found or not accessible", data={"code":"memory_not_accessible"})`.
   Do this validation before any write.
5. In ONE `tenant_tx`:
   - update the membership row (status, resolution_summary, resolved_by_memory_id, resolved_by_party,
     resolved_at=now()). Re-settling an already settled node is allowed (overwrites; logged again).
   - if a resolving node is named: insert the edge via `teams.references.insert_reference` (the same call
     `mindmap_link` uses) with `source_memory_id = resolved_by_memory_id`, `target_memory_id = node_id`,
     `target_team_id` = the settled node's team, `reference_kind` from the design-doc vocabulary:
     `resolved` → `"resolves-under"`, `dropped` → `"dropped-under"`. No resolving node → no edge.
   - append a map event via `service.log_event`: `event = "resolve"` for resolved, `"drop"` for dropped,
     `actor = resolved_by_party`, `memory_id = node_id`, payload with `disposition`,
     `resolved_by_memory_id` (str or None), `reference_kind` (or None). (Ids only in payload, no content.)
   - read the new cursor (see D) and return it.
   All SQL goes in `mindmap/service.py` (new functions, e.g. `get_membership`, `set_branch_status`,
   `current_cursor`, ...), with explicit `tenant_id` filters (defence-in-depth; the
   `tools/lint_tenant_scope.py` test must stay green). Put the disposition→edge-kind map and allowed values as
   constants in `mindmap/__init__.py`. Service functions raise their own exceptions / return None; the tool maps
   to `JsonRpcError`.

## C. `open_loops` fix (`mindmap_get`)
Design doc, whose-turn (`f5e52f08`): "open nodes carry `metadata.responsible_party` (`owner`|`model`);
`mindmap_get` returns the open set as the resume surface." So `open_loops` = member nodes with
`status == 'open'` AND `metadata.responsible_party in ('owner','model')`. A resolved/dropped node is never an
open loop. Compute open_loops over the whole map (independent of `since`/`include`) — it is just ids.
Update the `mindmap_get` tool description to match (it currently says owner-only).

## D. Cheap reads on `mindmap_get`
New input fields on `MindmapGetInput` (cheap defaults):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

New/changed output:
- `cursor: int` on `MindmapGetOutput` = `MAX(id)` of `memory_map_events` for this map (0 if none), read in the
  same transaction as the nodes. Every read returns it; writes/resolves advance it (they log events).
- `MindmapNode` gains `status: str` (always set) and `truncated: bool`; also add optional
  `resolution_summary: str | None = None` and `resolved_by_party: str | None = None` (filled for settled nodes
  when they appear in `nodes`).
- New output list `resolved: list[MindmapResolvedEntry]`, each `{memory_id, resolution_summary, status,
  resolved_by_party}`.
- All existing output fields stay.

Semantics:
- `since=N`: only members whose `memory_id` is referenced by a map event with `id > N` for this map
  (event `memory_id`, and for `link` events also the `payload->>'target'` id if it is a member). If no events
  after N: `nodes == []`, `resolved == []`, and `cursor == N`'s current value (unchanged). Never fall back to
  "everything". `since` larger than the current cursor → also empty.
- `include="open"`: `nodes` holds only `status == 'open'` members (root included, it is always open); settled
  members (within the since-window if given) go to `resolved` as compact entries, never in `nodes`.
  `include="all"`: every (window) member in `nodes` with its `status`; `resolved == []`.
- `depth="summary"`: if `len(content) > 200`, `content = content[:200] + "…"` (single U+2026 char) and
  `truncated=True`; otherwise content as-is, `truncated=False`. `depth="full"`: content whole,
  `truncated=False`. Put `200` as a constant (e.g. `SUMMARY_CONTENT_CHARS`) in `mindmap/__init__.py`.
  Applies to every node including the root.
- `edges`: keep internal-edge semantics, but restrict to edges where at least one endpoint is in the returned
  set (`nodes` ∪ `resolved`). With an empty window → `edges == []`.
- Do the filtering in the service/SQL where reasonable (e.g. `fetch_members` returns status columns; a
  `fetch_touched_member_ids(conn, root_memory_id, tenant_id, since)` helper); the tool stays thin.

Also update `mindmap_review` only if needed to keep it working (it uses `fetch_members`; adding columns is
fine). Update the `skills/mindmap-driver/SKILL.md` briefly: resolve branches with `mindmap_resolve`; resume
with `mindmap_get(since=<cursor>)`. Update the design doc's tool table with a `mindmap_resolve` row and a note
on status/cheap reads (short).

## Tests (do not modify existing tests; add new files)
- `tests/unit/test_mindmap_resolve_get_models.py` (DB-free): input validation (summary required, 1..500;
  disposition/party literals and defaults; `since` ge 0; include/depth defaults are "open"/"summary");
  truncation helper (exactly 200 chars → unchanged/false; 201 → 200 chars + "…", true; full → untouched).
- `tests/integration/test_mindmap_resolve_e2e.py` (DB-backed through the tools, reuse fixture style of
  `test_mindmap_e2e.py`, UUID-suffixed tenants/teams). Cover at least:
  1. resolve with resolving node → membership status/summary/party/resolved_at set; one
     `memory_references` row source=resolver, target=node, kind `resolves-under`; one `resolve` event; cursor
     increased vs previous get.
  2. drop without resolving node → status `dropped`, no edge row, event `drop`.
  3. drop with resolver → kind `dropped-under`.
  4. node of a different map (same tenant) → -32602, membership of that node unchanged, no edge, no event.
     Unknown map → -32602. Root node → -32602. Archived map (after `mindmap_close`) → -32602 `map_not_live`.
     Inaccessible/unknown resolver id → -32602 and nothing changed (transaction atomicity).
  5. `mindmap_link` with `resolves-under` alone does NOT settle the target (status stays open, still in
     open_loops).
  6. open_loops: owner-party and model-party open nodes are included; node without responsible_party is not;
     after resolve, the node disappears from open_loops.
  7. get defaults: `include=open` → resolved node absent from `nodes`, present in `resolved` with summary,
     status, party; `include=all` → present in `nodes` with status. Long content (>200) truncated with `…` and
     `truncated=True` by default; `depth=full` returns full content.
  8. `since=cursor` with no change → `nodes == []`, `resolved == []`, same cursor. After writing one new node →
     only that node returned. After resolving a node → it appears in `resolved` (include=open) for that window.
- Run: `alembic upgrade head`, then `pytest -q -p no:cacheprovider tests/unit tests/integration`, plus
  `ruff check src tests`, `ruff format --check` on changed files, `mypy`. Also run the full suite `pytest -q`
  before AND after (git stash is fine to get the baseline) and report the exact list of failures in both, so
  we can confirm no new failures.

## Report back
Files changed, exact test commands and results (pass/fail counts, failing test names before vs after), and any
design choices you had to make beyond this order.
