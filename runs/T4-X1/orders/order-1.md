# Work order 1 — Mind-map branch status, `mindmap_resolve`, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (esp. "Reference-kind vocabulary",
"Whose-turn", lifecycle/no-reopen), `src/mem_mcp/mindmap/service.py`,
`src/mem_mcp/mcp/tools/mindmap_*.py`, `alembic/versions/0038_2026_06_19_mindmap_tables.py`,
`tests/integration/test_mindmap_e2e.py` (how to drive tools against the real DB).

Layering: all SQL in `src/mem_mcp/mindmap/service.py`; tools stay thin; use `tenant_tx`;
errors via `JsonRpcError` (`mcp/errors.py`), same style as the existing mindmap tools.
Do NOT modify existing tests. Add new tests.

## A. Migration (new file `alembic/versions/0044_<date>_mindmap_branch_status.py`)

Follow existing naming: `revision = "0044_mindmap_branch_status"`, `down_revision = "0043_backfill_personal_teams"`,
docstring header like 0038. Add to `memory_map_membership`:

- `status TEXT NOT NULL DEFAULT 'open'` with `CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` with CHECK `char_length(resolution_summary) BETWEEN 1 AND 500` (when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL` with `CHECK (resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: `status = 'open'` ⇔ settlement columns are NULL; i.e.
  `(status = 'open' AND resolution_summary IS NULL AND resolved_by_party IS NULL AND resolved_at IS NULL AND resolved_by_memory_id IS NULL)
   OR (status IN ('resolved','dropped') AND resolution_summary IS NOT NULL AND resolved_by_party IS NOT NULL AND resolved_at IS NOT NULL)`
- Name every constraint explicitly. Existing rows default to `open`. RLS/grants already cover UPDATE (0038) — verify.
- `downgrade()` drops the constraints and columns.
- Run `alembic upgrade head`, then `alembic downgrade -1` and `alembic upgrade head` again to prove up/down works.

## B. Service functions (`mindmap/service.py`)

- `fetch_members` also returns `status, resolution_summary, resolved_by_memory_id, resolved_by_party, resolved_at`.
- `get_membership(conn, *, memory_id, root_memory_id)` → row or None (membership scoped to THIS map).
- `settle_branch(conn, *, memory_id, root_memory_id, status, resolution_summary, resolved_by_memory_id, resolved_by_party)`
  — UPDATE ... SET ..., resolved_at = now() WHERE memory_id=$ AND root_memory_id=$.
- `current_cursor(conn, *, root_memory_id) -> int` — `COALESCE(MAX(id), 0)` from `memory_map_events` for the map.
- `touched_since(conn, *, root_memory_id, since) -> set[UUID]` — memory ids touched by this map's events with `id > since`:
  the event's `memory_id`, plus any memory UUID the event payload names as `target` (link events) or
  `resolved_by_memory_id`. Ignore null / non-member ids (the caller intersects with members).
- Make `log_event` return the new event id (`RETURNING id`) — existing callers can ignore it.

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`

Classes `MindmapResolveTool` (name `"mindmap_resolve"`, `required_scope = "memory.write"`),
`MindmapResolveInput`, `MindmapResolveOutput`. Register in `src/mem_mcp/main.py` exactly like the other
mindmap tools, and add a `TOOL_DESCRIPTIONS["mindmap_resolve"]` entry in `mcp/tool_descriptions.py` in the
existing "Call when / Do not call for / Example" style (also check whether any test enumerates registered
tools/descriptions and must stay consistent).

Input:
- `map_key: str = Field(..., min_length=1, max_length=64)`
- `node_id: UUID`
- `disposition: Literal["resolved","dropped"] = "resolved"`
- `resolution_summary: str = Field(..., min_length=1, max_length=500)` (required)
- `resolved_by_memory_id: UUID | None = None`
- `resolved_by_party: Literal["owner","model"] = "model"`
- `team_id: UUID | None = None`

Output: `node_id: UUID`, `status: str`, `resolution_summary: str`, `cursor: int`, `request_id: str`.

Behaviour:
1. If `resolved_by_memory_id` is given: resolve it exactly as `mindmap_link` does
   (`resolve_reference_target` in a `system_tx`; on `ReferenceTargetNotFoundError` → `JsonRpcError(-32602, ..., data={"code": "memory_not_accessible"})`).
   If `resolved_by_memory_id == node_id` → -32602 (a node cannot settle itself).
2. In ONE `tenant_tx`:
   - resolve team + map root; unknown map → `JsonRpcError(-32602, "map not found", data={"errors":[{"path":"map_key"}]})`.
   - map not live (archived) → `JsonRpcError(-32602, ..., data={"code": "map_not_live"})` (no-reopen lifecycle rule; nothing changes).
   - `get_membership(node_id, root)`; None (unknown node, or a node owned by a DIFFERENT map) →
     `JsonRpcError(-32602, "node is not a member of this map", data={"errors":[{"path":"node_id"}]})`, nothing changed.
   - the root node (`node_role == 'root'`) is not a branch → -32602 (settling the root = closing the map; use `mindmap_close`).
   - Re-settling an already settled node is allowed (overwrites settlement, e.g. resolved → dropped).
   - `settle_branch(...)`.
   - If `resolved_by_memory_id` given: `insert_reference(conn, source_memory_id=resolved_by_memory_id,
     target_memory_id=node_id, target_team_id=<node's team — resolve node_id via resolve_reference_target
     too, like mindmap_link resolves its target>, reference_kind=...)` with kind
     `"resolves-under"` for `resolved` and `"dropped-under"` for `dropped` (design-doc vocabulary). Same
     `insert_reference` function mindmap_link uses. No resolving node → no edge.
   - `log_event(event="resolve", actor=inp.resolved_by_party, memory_id=node_id, payload={"disposition":..., "resolution_summary":..., "resolved_by_memory_id": str|None, "reference_kind": str|None})`.
   - cursor = id returned by log_event (or `current_cursor` afterwards).
   Any failure rolls the whole transaction back (status + edge + event together).

## D. `mindmap_get` changes

New input fields (defaults = cheap):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

New/changed output:
- `MindmapNode` gains `status: str` and `truncated: bool`.
- New model `MindmapResolvedEntry { memory_id: UUID, resolution_summary: str, status: str, resolved_by_party: str }`.
- `MindmapGetOutput` gains `cursor: int` and `resolved: list[MindmapResolvedEntry]`. All existing fields stay.

Semantics (compute in the tool from service results; keep the read in the existing `tenant_tx`):
- `cursor` = `current_cursor` for the map, read in the same transaction.
- Candidate set = all members; if `since` is not None, restrict to members in `touched_since(since)`.
  If nothing changed since → `nodes == []`, `resolved == []`, `edges == []`, same cursor. Never fall back to everything.
- `include="open"`: `nodes` = candidates with status `open`; settled candidates go to `resolved` (compact entries).
  `include="all"`: `nodes` = all candidates (each with its status); `resolved` is still populated with the settled
  candidates' compact entries (harmless; document it).
- `depth="summary"`: if `len(content) > 200` → `content[:200] + "…"` (single U+2026 char), `truncated=True`;
  otherwise content as-is, `truncated=False`. `depth="full"` → whole content, `truncated=False`.
- `edges`: internal edges (as today) restricted to those with at least one endpoint among returned
  `nodes` ∪ `resolved` ids.
- `open_loops` (fix): computed over the FULL membership (not narrowed by `since`/`include`), per the design
  doc's whose-turn rule: members whose status is `open` AND whose `metadata.responsible_party` is set
  (`owner` or `model` — the doc: "open nodes carry metadata.responsible_party (owner|model)"). A resolved/dropped
  node is never an open loop. Exclude the root.
- `review_due`, `state`, etc. unchanged.
- Update the module docstring and `TOOL_DESCRIPTIONS["mindmap_get"]` to describe the levers, the cursor,
  `resolved`, and the corrected open_loops meaning. Also update `skills/mindmap-driver/SKILL.md` briefly
  (resume with `since=<cursor>`; settle branches with `mindmap_resolve`).

## E. Tests (new files only)

- `tests/unit/test_mindmap_resolve_unit.py` (or similar): input validation (summary required, 1..500, disposition/party
  literals, defaults), summary truncation helper (exactly 200 chars → unchanged/false; 201 → 200 + "…"/true; full depth).
- `tests/integration/test_mindmap_branch_status.py`, DB-backed through the tools (copy the setup of
  `test_mindmap_e2e.py`), covering at least:
  1. resolve with resolving node → status resolved, `resolves-under` edge source=resolver target=node exists in
     `memory_references`, event logged, cursor advanced; dropped → `dropped-under`; no resolver → no edge but settled.
  2. node of a different map / random UUID / unknown map → -32602 and nothing changed (status still open, no edge, no event).
  3. archived map → -32602 `map_not_live`.
  4. open_loops excludes resolved/dropped; includes open owner and model nodes.
  5. get defaults: settled branch absent from `nodes`, present in `resolved` with summary/status/party; `include="all"` shows all with status.
  6. `since=cursor` with no changes → no nodes, same cursor; after a write_node / resolve → only the touched node(s), new cursor.
  7. depth summary/full truncation on a >200-char node, `truncated` flags.
  8. DB CHECK constraints reject an invalid status value / an open row with a summary.

## Verify and report

- `alembic upgrade head` (+ downgrade -1 / upgrade head round trip)
- `pytest -q -p no:cacheprovider tests/unit tests/integration` — report pass/fail counts; run the full suite on
  the baseline commit too (`git stash` is fine) or otherwise identify which failures are pre-existing, and confirm
  you introduced none.
- `ruff check src tests` and `mypy` clean for your files.
Report: files changed, exact test commands + results, open questions.
