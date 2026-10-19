# Work order 1 — Mind-map branch status, `mindmap_resolve`, open_loops fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth for mind-map rules),
`docs/adr/0008-*.md`, `skills/mindmap-driver/SKILL.md`, `src/mem_mcp/mindmap/service.py`,
`src/mem_mcp/mcp/tools/mindmap_*.py`, `src/mem_mcp/mcp/tools/_mindmap_common.py`,
`src/mem_mcp/teams/references.py`, `alembic/versions/0038_2026_06_19_mindmap_tables.py`,
`tests/integration/test_mindmap_e2e.py` (fixture pattern for DB-backed tool tests).

## Problem
Every `mindmap_get` returns every node in full. There is no per-branch status (only the whole map can be
closed), so `open_loops` only grows. We add stored branch status, a tool to settle one branch, and cheap
read levers on `mindmap_get`.

## A. Migration (new file `alembic/versions/0044_2026_10_15_mindmap_branch_status.py`)
`revision = "0044_mindmap_branch_status"`, `down_revision = "0043_backfill_personal_teams"`. Docstring explains
why (per-branch settlement; status is stored, never inferred from `memory_references.reference_kind`, which is
unvalidated free text). Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` with CHECK `char_length(resolution_summary) BETWEEN 1 AND 500` (when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL CHECK (resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: `status = 'open'` ⇔ (`resolution_summary`, `resolved_by_party`, `resolved_at` all NULL);
  settled ⇒ those three NOT NULL. (`resolved_by_memory_id` optional when settled, NULL when open.)
- Use named constraints; `downgrade()` drops the columns/constraints. Existing rows default to `open`.
- Also add an index on `memory_map_events (root_memory_id, id)` to support cursor reads.
Then run `alembic upgrade head` (and verify downgrade -1 / upgrade head round-trips).

## B. Service layer (`src/mem_mcp/mindmap/service.py`) — all SQL lives here
Keep the style (thin, deterministic, takes `asyncpg.Connection`, no `JsonRpcError`). Every query on
per-tenant tables must also filter `tenant_id = $n` explicitly (defence in depth; the
`tests/unit/test_lint_tenant_scope.py` real-codebase test must stay clean). Add e.g.:
- `BRANCH_STATUSES` / settled-status constants (could live in `mindmap/__init__.py` next to existing constants).
- `lock_map_row(conn, root_memory_id, tenant_id)` → map row `FOR UPDATE` (so resolve can't race a close).
- `get_membership_for_update(conn, memory_id, root_memory_id, tenant_id)` → membership row of that node **in
  that map** (join `memories`, `deleted_at IS NULL`), `FOR UPDATE`, or None.
- `memory_visible_in_tenant(conn, memory_id, tenant_id)` → bool (non-deleted memory of this tenant).
- `set_branch_status(conn, *, memory_id, root_memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)` → UPDATE … `resolved_at = now()` RETURNING row.
- `current_cursor(conn, root_memory_id, tenant_id)` → `COALESCE(MAX(id), 0)` over `memory_map_events` of that map.
- `touched_member_ids_since(conn, root_memory_id, tenant_id, since)` → set of memory ids touched by events with
  `id > since`: the event's `memory_id`, plus `payload->>'target'` (link events) and any other node id your
  resolve event payload names as the settled node. Only ids that are members of this map matter (filter later).
- `log_event` should return the new event id (`RETURNING id`) — existing callers ignore the return value.
- `fetch_members` must also return `status, resolution_summary, resolved_by_memory_id, resolved_by_party,
  resolved_at`.

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `mindmap_resolve`, scope `memory.write`), `MindmapResolveInput`
(`model_config = ConfigDict(extra="forbid")`), `MindmapResolveOutput`.

Input: `map_key: str (1..64)`, `node_id: UUID`, `disposition: Literal["resolved","dropped"] = "resolved"`,
`resolution_summary: str (min_length=1, max_length=500)` **required** (also reject whitespace-only),
`resolved_by_memory_id: UUID | None = None`, `resolved_by_party: Literal["owner","model"] = "model"`,
`team_id: UUID | None = None`.
Output: `node_id`, `status`, `resolution_summary`, `cursor: int`, `request_id`.

Behaviour:
1. Resolve team + map root like the other mindmap tools. Unknown map → `JsonRpcError(-32602, "map not found",
   data={"errors": [{"path": "map_key"}]})`.
2. If `resolved_by_memory_id` is given: it must differ from `node_id` and be a non-deleted memory visible to this
   tenant, else -32602 with `data={"code": "memory_not_accessible", "errors":[{"path":"resolved_by_memory_id"}]}`.
   To obtain `target_team_id` for the edge, reuse the same path as `mindmap_link`
   (`resolve_reference_target` in a `system_tx` before the write tx), mapping its not-found to the same
   "node not in map" error as step 3b (opaque).
3. In ONE `tenant_tx` (atomic — status, edge, event all commit or none):
   a. lock the map row; if `state != 'live'` → -32602 `data={"code": "map_not_live"}` (no-reopen / archived maps
      are immutable — design doc lifecycle).
   b. lock the node's membership row **in this map**. Not a member of this map (including a node of a different
      map, a non-existent id, a deleted node) → `JsonRpcError(-32602, "node is not a member of this map",
      data={"errors": [{"path": "node_id"}]})` — identical for all those cases (no existence oracle). Nothing
      changes.
   c. The map root (`node_role == 'root'`) cannot be settled → -32602 with path `node_id` (settling the whole map is
      `mindmap_close`).
   d. Re-settling an already-settled branch is allowed (it overwrites disposition/summary/etc.).
   e. update status via the service.
   f. if `resolved_by_memory_id` given: `insert_reference(conn, source_memory_id=resolved_by_memory_id,
      target_memory_id=node_id, target_team_id=..., reference_kind=...)` — the same helper `mindmap_link` uses —
      with `reference_kind = "resolves-under"` for `resolved` and `"dropped-under"` for `dropped` (design doc
      reference-kind vocabulary). Put these two strings in named constants. No resolving node → no edge.
   g. `log_event(event="resolve", actor=resolved_by_party, memory_id=node_id, payload={"disposition",
      "resolved_by_memory_id", "reference_kind" (or null)})` — never log the summary text? (Summary is a short
      one-liner the model wrote; it's fine to omit it from the payload — keep payload to ids/enums.)
   h. read the new cursor (= the event id just written) and return it.
4. Register in `src/mem_mcp/main.py` with the other mindmap tools; add a `TOOL_DESCRIPTIONS["mindmap_resolve"]`
   entry in `mcp/tool_descriptions.py` in the existing "Call when / Do not call for / Examples" style.

## D. `mindmap_get` changes (`src/mem_mcp/mcp/tools/mindmap_get.py`)
New input fields (defaults = cheap):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

New output: `cursor: int`, `resolved: list[MindmapResolvedEntry]` (each `memory_id`, `resolution_summary`,
`status`, `resolved_by_party`; you may add `resolved_by_memory_id`, `resolved_at`). `MindmapNode` gains
`status: str` and `truncated: bool`. All existing output fields stay.

Semantics (read everything in one `tenant_tx`, cursor read in the same tx):
- `cursor` = current max event id of this map (0 if none). Always returned.
- Candidate set: all live (non-deleted) members. If `since` is not None, restrict to members touched by events
  with `id > since`; if nothing changed → `nodes == []`, `resolved == []`, same cursor. Never "everything".
- `include="open"`: `nodes` = candidates with status `open`; settled candidates go to `resolved` (compact entries,
  no content). `include="all"`: every candidate in `nodes` (with its `status`), and `resolved` is empty.
- `depth="summary"`: content longer than 200 chars → `content[:200] + "…"` (single U+2026), `truncated=True`;
  ≤ 200 chars unchanged, `truncated=False`. `depth="full"`: whole content, `truncated=False`. Constant
  `SUMMARY_CONTENT_CHARS = 200`.
- `edges`: internal edges with at least one endpoint among the ids returned in `nodes` ∪ `resolved` (for a full
  `include="all"` read without `since` this is identical to today's output).
- `open_loops` (always computed over the whole map, independent of since/include): design doc whose-turn rule —
  "open nodes carry `metadata.responsible_party` (`owner`|`model`)"; the open set is the resume surface. So
  `open_loops` = members with `status == 'open'` whose `metadata.responsible_party` is `owner` **or** `model`.
  A resolved/dropped node is never an open loop. Never infer status from edges.
- Update the module docstring and the `mindmap_get` tool description (document since/include/depth/cursor and
  that cheap is the default).

## E. Docs
- `skills/mindmap-driver/SKILL.md`: add a short "Settle a branch" section (`mindmap_resolve`, one-line summary,
  `resolved_by_memory_id`) and a "Resume cheaply" note (keep the cursor; `mindmap_get(since=cursor)`;
  `depth="full"` / `include="all"` only when needed).
- `docs/mindmap-v1-build-design.md`: add `mindmap_resolve` to the tool table and note the per-branch status
  columns in the membership table sketch. Keep it brief.

## F. Tests (add new files; do not modify existing tests)
- `tests/unit/test_mindmap_get_shaping.py` (DB-free where possible): truncation boundary (exactly 200 → unchanged,
  201 → 200 chars + "…" and `truncated=True`, full depth), input model defaults and validation (since<0 rejected,
  bad include/depth rejected, resolve input: summary required/empty/501 chars rejected, bad disposition/party
  rejected, extra fields rejected). Factor shaping into small pure helpers if that makes them testable.
- `tests/integration/test_mindmap_resolve_e2e.py` (DB-backed through the tools, fixture modelled on
  `test_mindmap_e2e.py`, UUID-suffixed tenant/emails). Cover at least:
  1. resolve with resolving node → status row stored, edge `resolves-under` (source=resolver, target=node) exists
     in `memory_references`, `resolve` event logged, returned cursor > previous cursor.
  2. dropped with resolving node → `dropped-under` edge; dropped without resolver → no new edge, still settled.
  3. node of a *different* map (same tenant) → -32602, nothing changed in either map; random UUID → same error;
     unknown map → -32602; root node → -32602.
  4. archived map (after `mindmap_close`) → -32602 `map_not_live`.
  5. an edge drawn with `mindmap_link(reference_kind="resolves-under")` alone does NOT settle the branch
     (still open, still in open_loops if it has a responsible_party).
  6. open_loops: owner-turn and model-turn open nodes included; node without responsible_party excluded; after
     resolve, excluded.
  7. get defaults: settled node absent from `nodes`, present in `resolved` with summary/status/party; `include="all"`
     returns it in `nodes` with `status`; long node truncated in summary depth, full in `depth="full"`.
  8. `since`: get → cursor c; get(since=c) → no nodes, same cursor; write a node → get(since=c) returns only that
     node and a larger cursor; resolve a node → get(since=c2) returns it in `resolved` (include=open).
  9. Atomicity: if the edge insert fails (e.g. monkeypatch the reference insert to raise), the status update is
     rolled back (node still open, no resolve event).

## Acceptance / verification (report exact commands + results)
- `alembic upgrade head`; `alembic downgrade -1 && alembic upgrade head`.
- `pytest -q -p no:cacheprovider tests/unit/test_mindmap_get_shaping.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py`
- `pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py`
- Full suite `pytest -q -p no:cacheprovider` — report the list of failing tests and confirm (e.g. via
  `git stash` comparison) that each was failing before your change.
- `ruff check src tests`, `ruff format --check` on the files you touched, `mypy` — clean for your files.
Report files changed and any deviations from this order with reasons.
