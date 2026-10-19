# Work order 1 — Mind-map branch status, `mindmap_resolve`, open_loops fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md`, `skills/mindmap-driver/SKILL.md`,
`src/mem_mcp/mindmap/service.py`, `src/mem_mcp/mindmap/__init__.py`, all `src/mem_mcp/mcp/tools/mindmap_*.py`,
`src/mem_mcp/mcp/tools/_mindmap_common.py`, `src/mem_mcp/teams/references.py`,
`alembic/versions/0038_2026_06_19_mindmap_tables.py`, `tests/integration/test_mindmap_e2e.py`.

## Problem
`mindmap_get` returns every node in full every time; there is no per-branch settlement (only
`mindmap_close` settles the whole map), so `open_loops` only ever grows. Build branch status, a
`mindmap_resolve` tool, fix `open_loops`, and add cheap read levers to `mindmap_get`.

## A. Stored branch status — new Alembic migration
File `alembic/versions/0044_2026_10_16_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`. Docstring explaining *why* (as peers do). Forward SQL via
`op.execute(sa.text(...))`, with a real `downgrade()` that drops what you added.

Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` with CHECK `char_length(resolution_summary) BETWEEN 1 AND 500` (when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL CHECK (resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: `status = 'open'` ⇒ resolution_summary, resolved_by_memory_id, resolved_by_party,
  resolved_at all NULL; `status <> 'open'` ⇒ resolution_summary, resolved_by_party, resolved_at NOT NULL.
Name the constraints explicitly. Existing rows default to `open`. Existing RLS policies/grants on the
table already cover the new columns (verify; no new table needed). Optionally an index on
`memory_map_events(root_memory_id, id)` to make cursor reads cheap.

Status is the ONLY source of truth for "settled". Never infer it from `memory_references.reference_kind`
(an edge alone never settles a branch).

Run `alembic upgrade head` after adding it (and check `alembic downgrade -1` then `upgrade head` again works).

## B. Service layer (`src/mem_mcp/mindmap/service.py`) — all SQL lives here
Domain functions take an `asyncpg.Connection`, never import `JsonRpcError`; every query on per-tenant
tables carries an explicit `tenant_id = $n` filter in addition to RLS (the lint test
`tests/unit/test_lint_tenant_scope.py` must stay green). Suggested functions:
- `log_event(...)` → change to `RETURNING id` and return the new event id (`int`). Existing callers may
  ignore the return value.
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int`: `COALESCE(MAX(id), 0)` of the map's events.
- `get_member(conn, *, root_memory_id, memory_id, tenant_id) -> dict | None`: the membership row only if
  the node is a member of **this** map.
- `settle_branch(conn, *, root_memory_id, memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)`: UPDATE the membership row (set `resolved_at = now()`),
  WHERE also on root_memory_id + tenant_id.
- `touched_member_ids_since(conn, *, root_memory_id, tenant_id, since) -> set[UUID]`: distinct
  `memory_id` of map events with `id > since` (non-null memory_id).
- `fetch_members` must also return `status, resolution_summary, resolved_by_memory_id,
  resolved_by_party, resolved_at`.
- Add the constants to `src/mem_mcp/mindmap/__init__.py`: `BRANCH_STATUSES = ("open","resolved","dropped")`,
  `SUMMARY_CONTENT_CHARS = 200`, and the disposition→edge-kind map
  `RESOLUTION_REFERENCE_KINDS = {"resolved": "resolves-under", "dropped": "dropped-under"}`
  (from the design doc's reference-kind vocabulary).

## C. New tool `mindmap_resolve` — `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `"mindmap_resolve"`, `required_scope = "memory.write"`,
`description = TOOL_DESCRIPTIONS["mindmap_resolve"]`), `MindmapResolveInput`, `MindmapResolveOutput`.

Input (`model_config = ConfigDict(extra="forbid")`):
| field | type |
|---|---|
| `map_key` | `str`, Field(min_length=1, max_length=64) |
| `node_id` | `UUID` |
| `disposition` | `Literal["resolved","dropped"] = "resolved"` |
| `resolution_summary` | `str`, Field(..., min_length=1, max_length=500) — required |
| `resolved_by_memory_id` | `UUID \| None = None` |
| `resolved_by_party` | `Literal["owner","model"] = "model"` |
| `team_id` | `UUID \| None = None` |

Output: `node_id: UUID`, `status: str` (new status), `resolution_summary: str`, `cursor: int`,
`request_id: str`.

Behaviour:
1. Resolve team + map like the other tools (`resolve_team_id`, `service.resolve_map_root`). Unknown map →
   `JsonRpcError(-32602, "map not found", data={"errors": [{"path": "map_key"}]})`.
2. Map lifecycle: archived map → `JsonRpcError(-32602, ..., data={"code": "map_not_live"})` (no-reopen; a
   closed map is not mutated). Nothing changes.
3. `node_id` not a member of THIS map (including: member of another map, unmapped, nonexistent, other
   tenant) → `JsonRpcError(-32602, "node not found in map", data={"errors": [{"path": "node_id"}]})` —
   same error for all those cases (opaque). Nothing changes.
4. The root node (`node_id == root_memory_id`) is the map itself, not a branch → -32602 with
   `errors path node_id` (settle the whole map with `mindmap_close`).
5. If `resolved_by_memory_id` is given: it must not equal `node_id` (-32602, path
   `resolved_by_memory_id`); it must exist and be accessible to the caller — check it via
   `resolve_reference_target(sys_conn, target_uuid=..., caller_user_id=ctx.tenant_id)` inside
   `system_tx` exactly as `mindmap_link` does; map `ReferenceTargetNotFoundError` to
   `JsonRpcError(-32602, "reference target not found or not accessible", data={"code": "memory_not_accessible"})`.
   Do the access checks BEFORE any write.
6. In ONE `tenant_tx`: (re-)check map is live and node is a member (lock-safe: do the membership lookup
   and the update in the same tx), `service.settle_branch(...)`; if a resolving node was named,
   `insert_reference(conn, source_memory_id=resolved_by_memory_id, target_memory_id=node_id,
   target_team_id=<team of the settled node — use the map's team_id from memory_maps>,
   reference_kind=RESOLUTION_REFERENCE_KINDS[disposition])` (the same `teams.references.insert_reference`
   path `mindmap_link` uses); then `service.log_event(event="resolve" for resolved / "drop" for dropped,
   actor=resolved_by_party, memory_id=node_id, payload={"disposition", "resolved_by_memory_id" (str|None),
   "reference_kind" (str|None)})` — ids only, no content. The returned event id is the output `cursor`.
   No resolving node → no edge, branch still settled.
7. Re-settling an already-settled branch (e.g. resolved → dropped, or a new summary) is allowed: it
   overwrites the settlement and logs a new event. There is no way back to `open` via this tool.

Register in `src/mem_mcp/main.py` next to the other mindmap tools. Add a `TOOL_DESCRIPTIONS["mindmap_resolve"]`
entry in `src/mem_mcp/mcp/tool_descriptions.py` in the house style (what it does, "Call when: …",
"Do not call for: …" — e.g. closing the whole map → mindmap_close, drawing an arbitrary edge →
mindmap_link — "Examples: … → …", required scope). If any test or registry enumerates tools/descriptions
(grep tests for e.g. `mindmap_close` / tool-name lists), make sure the new tool is consistent with it.

## D. `open_loops` fix (in `mindmap_get`)
Design doc, whose-turn (`f5e52f08`): "open nodes carry `metadata.responsible_party` (`owner`|`model`);
`mindmap_get` returns the open set as the resume surface." So `open_loops` = member ids whose
`metadata.responsible_party` is `"owner"` or `"model"` AND whose stored `status == "open"`. Nodes without
a responsible_party are not loops; a resolved/dropped node is NEVER an open loop. Compute `open_loops`
over the whole map regardless of `since`/`include` (it's ids only). Update the module docstring and the
`mindmap_get` tool description accordingly (the current text says owner-only).

## E. Cheap reads on `mindmap_get`
New input fields on `MindmapGetInput` (defaults = cheap):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

New output fields on `MindmapGetOutput` (keep all existing ones):
- `cursor: int` — current max event id of the map (0 if none). Every read returns it.
- `resolved: list[MindmapResolvedEntry]` with `memory_id: UUID`, `resolution_summary: str`,
  `status: str`, `resolved_by_party: str` (default empty list).
`MindmapNode` gains `status: str` and `truncated: bool` (also add optional `resolution_summary: str | None = None`
so `include="all"` shows the settlement line).

Algorithm (read everything in one `tenant_tx`, capture the cursor in the same tx):
1. members = all members (with status).
2. If `since` is not None: keep only members whose id is in `touched_member_ids_since(since)`. If nothing
   changed → `nodes == []`, `resolved == []`, and `cursor == since` (the current cursor, which equals it).
   Never fall back to "everything".
3. `include="open"`: `nodes` = selected members with status `open`; selected settled members go to
   `resolved` (compact entries). `include="all"`: `nodes` = every selected member (each with its status),
   `resolved` = [].
4. `depth="summary"`: content longer than 200 chars → `content[:200] + "…"` (single U+2026 char),
   `truncated=True`; ≤200 chars → unchanged, `truncated=False`. `depth="full"` → whole content,
   `truncated=False`. Put the truncation in a small pure helper (unit-testable).
5. `edges`: internal edges (both endpoints map members) filtered to those with at least one endpoint
   among the returned `nodes` ∪ `resolved` ids (with `include="all"`, no `since` this equals today's
   behaviour).
6. `open_loops`: per D.

`mindmap_get` on an archived map must still work. Update the tool description to document the levers
("call with `since=<last cursor>` on resume to fetch only changes; `include='all'`/`depth='full'` only
when you need the whole map").

## F. Docs
- `skills/mindmap-driver/SKILL.md`: a short "Settle a branch" section (call `mindmap_resolve` with a
  one-line summary when a branch is answered/abandoned; resume with `mindmap_get(since=<cursor>)`).
- `docs/mindmap-v1-build-design.md`: add `mindmap_resolve` to the tool table and document the stored
  branch status columns + cheap-read levers (short).

## G. Tests (do NOT modify existing tests; add new files)
- Unit: `tests/unit/test_mindmap_cheap_reads.py` — truncation helper (199/200/201 chars, exactly 201
  output length with trailing `…`), input model defaults/validation (`since` ≥ 0, literals, summary
  1..500 required, extra fields forbidden), resolve input defaults.
- DB-backed integration `tests/integration/test_mindmap_resolve.py`, modelled on
  `tests/integration/test_mindmap_e2e.py` (UUID-suffixed fixtures, cleanup), covering at least:
  - resolve with resolving node: status `resolved` stored on membership row with summary/party/
    resolved_at/resolved_by; a `resolves-under` edge source=resolver → target=node; event row logged;
    output cursor > previous cursor.
  - drop without resolving node: status `dropped`, NO edge written, still settled.
  - `dropped` with resolver → `dropped-under` edge.
  - node from a DIFFERENT map (same tenant) → -32602, nothing changed in either map; unknown map →
    -32602; random uuid → -32602; root node → -32602; archived map → -32602 `map_not_live`;
    inaccessible/nonexistent resolver → -32602 and nothing written (no status change).
  - an edge alone (via `mindmap_link` with `resolves-under`) does NOT settle a branch: node stays `open`
    and remains in open_loops.
  - open_loops: owner and model responsible nodes both included while open; node without
    responsible_party excluded; resolved/dropped excluded.
  - get defaults: settled nodes absent from `nodes`, present in `resolved` with the right fields; long
    content truncated with `truncated=True`; `include="all"` returns all with statuses; `depth="full"`
    returns whole content.
  - cursor: read returns cursor; `since=cursor` with no changes → `nodes == []`, `resolved == []`,
    same cursor; after a write_node / resolve → only the touched node(s) returned and cursor advanced.
  - migration CHECKs: a direct UPDATE setting `status='bogus'` raises `CheckViolationError`.

## Acceptance / verification — report exact results
1. `alembic upgrade head` succeeds (also downgrade -1 / upgrade head round-trip).
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_cheap_reads.py tests/integration/test_mindmap_resolve.py tests/integration/test_mindmap_e2e.py` all green.
3. Full suite `pytest -q -p no:cacheprovider` — report pass/fail counts and list every failing test; for
   each failure confirm it is pre-existing (e.g. by `git stash`-ing your changes and re-running that test,
   then `git stash pop` — be careful to restore everything) or fix it if you caused it.
4. `ruff check src tests` and `mypy` clean for the files you touched (report output).
Reply with: files changed, test commands + exact results, any open questions/deviations from this order.
