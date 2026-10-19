# Work order 1 — Mind-map branch status, `mindmap_resolve`, open_loops fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth where this order is silent),
`src/mem_mcp/mindmap/service.py`, `src/mem_mcp/mcp/tools/mindmap_*.py`, `_mindmap_common.py`,
`alembic/versions/0038_2026_06_19_mindmap_tables.py`, `tests/integration/test_mindmap_e2e.py` (fixture pattern).

## Problem
`mindmap_get` returns every node in full every time; there is no per-branch settlement (only whole-map
`mindmap_close`), so `open_loops` only grows. Build stored branch status, a `mindmap_resolve` tool, fix
`open_loops`, and add cheap read levers to `mindmap_get`.

## A. Migration (stored status)
New file `alembic/versions/0044_2026_10_15_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`, docstring explaining *why* (branch settlement must be stored
state, never inferred from the unvalidated free-text `memory_references.reference_kind`). Add columns to
`memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` (CHECK length 1..500 when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL CHECK (resolved_by_party IS NULL OR resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: `status='open'` ⇒ summary/party/resolved_at/resolved_by_memory_id all NULL;
  `status IN ('resolved','dropped')` ⇒ summary, party, resolved_at NOT NULL.
Name the constraints explicitly; `downgrade()` drops them/the columns. Existing RLS/grants already cover the
table. Run `alembic upgrade head` (and verify downgrade -1 / upgrade head round-trips).

## B. Service layer (`mindmap/service.py`) — all SQL goes here
Add thin functions (explicit `tenant_id = $n` filters on per-tenant tables, defence in depth; the tenant-scope
linter test `tests/unit/test_lint_tenant_scope.py` must stay green):
- `get_membership(conn, *, memory_id, root_memory_id, tenant_id) -> dict | None` — the membership row of this node
  **in this map** (joined to non-deleted `memories`); None if it is not a member of that map.
- `set_branch_status(conn, *, memory_id, root_memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)` — UPDATE … `resolved_at = now()` scoped by memory_id AND
  root_memory_id AND tenant_id.
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int` — `COALESCE(MAX(id), 0)` from `memory_map_events`
  for this map.
- `fetch_touched_since(conn, *, root_memory_id, tenant_id, since) -> set[UUID]` — memory ids touched by this map's
  events with `id > since`: the event's `memory_id`, plus `payload->>'target'` (link events) and
  `payload->>'node_id'` if present. Caller intersects with members.
- Make `log_event` return the new event id (`RETURNING id`) — callers that ignore it keep working.
- `fetch_members` must also return `status, resolution_summary, resolved_by_memory_id, resolved_by_party,
  resolved_at`.
Domain code must not import `JsonRpcError`; return None / raise own exceptions and let the tool map them.

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `mindmap_resolve`, scope `memory.write`), `MindmapResolveInput`
(`model_config = ConfigDict(extra="forbid")`), `MindmapResolveOutput`.

Input: `map_key: str (1..64)`, `node_id: UUID`, `disposition: Literal["resolved","dropped"] = "resolved"`,
`resolution_summary: str (1..500, required)`, `resolved_by_memory_id: UUID | None = None`,
`resolved_by_party: Literal["owner","model"] = "model"`, `team_id: UUID | None = None`.
Output: `node_id`, `status`, `resolution_summary`, `cursor: int`, `request_id`.

Behaviour (all errors are `JsonRpcError(-32602, …)` and **nothing is changed** when one is raised):
1. Resolve team + map like the other tools. Unknown map → -32602 `"map not found"`,
   `data={"errors":[{"path":"map_key"}]}`.
2. Map not live (archived) → -32602 `data={"code":"map_not_live"}` (no-reopen lifecycle rule: archived maps are
   immutable).
3. `node_id` not a member of **this** map (including: member of a different map, nonexistent, other tenant) →
   -32602, `data={"errors":[{"path":"node_id","message":"node is not a member of this map"}]}` — same response for
   all those cases (opaque).
4. `node_id` is the map's root (`node_role == 'root'`) → -32602 path `node_id` (settling the whole map is
   `mindmap_close`).
5. If `resolved_by_memory_id` is given: it must be a member of the same map and differ from `node_id`, else
   -32602 path `resolved_by_memory_id`. Then record the edge **source = resolving node, target = settled node**
   using the same path as `mindmap_link`: `resolve_reference_target` (in `system_tx`, mapping
   `ReferenceTargetNotFoundError` the same way mindmap_link does) then `teams.references.insert_reference`.
   Edge kind from the design doc's vocabulary: `resolved` → `"resolves-under"`, `dropped` → `"dropped-under"`
   (put these as UPPER_CASE constants, e.g. in `mindmap/__init__.py`). No resolving node → no edge, branch still
   settled.
6. Status update + edge insert + event log happen in **one** `tenant_tx`. Do all validation lookups so that a
   failure aborts before any write (validation reads may be in the same tx; the read-only `system_tx` reference
   resolution may run before it).
7. Log event `event="resolve"`, `actor=resolved_by_party`, `memory_id=node_id`, payload
   `{"disposition", "resolved_by_memory_id" (str|None), "reference_kind" (or None)}` (no content/summary text in
   logs is fine to include in payload? — include `resolution_summary` in payload is NOT needed; keep ids only).
8. Re-resolving an already-settled node on a live map is allowed (overwrites status/summary; logs another event).
9. Output `cursor` = id of the event just logged (== current cursor).

Register in `src/mem_mcp/main.py` (import + tool list next to the other mindmap tools). Add a
`TOOL_DESCRIPTIONS["mindmap_resolve"]` entry in `mcp/tool_descriptions.py` in the house style (what it does,
"Call when: …", "Do not call for: …" (e.g. closing the whole map → mindmap_close; drawing an arbitrary edge →
mindmap_link), "Example: … → …").

## D. `open_loops` fix (in `mindmap_get`)
Design doc whose-turn (`f5e52f08`): open nodes carry `metadata.responsible_party` ∈ {`owner`,`model`} and the open
set is the resume surface. So `open_loops` = members whose `responsible_party` is `owner` **or** `model` **and**
whose stored `status == 'open'`. A resolved/dropped node is never an open loop. Do not use `reference_kind`
anywhere to decide settlement. `open_loops` is always computed over the whole map (not filtered by `since`).
Update the module docstring accordingly.

## E. Cheap reads on `mindmap_get`
New `MindmapGetInput` fields (defaults = cheap): `since: int | None = Field(default=None, ge=0)`,
`include: Literal["open","all"] = "open"`, `depth: Literal["summary","full"] = "summary"`.
`MindmapNode` gains `status: str`, `truncated: bool`, and optional `resolution_summary: str | None = None`
(set for settled nodes in include="all"). New output fields: `cursor: int`, `resolved: list[MindmapResolvedEntry]`
where `MindmapResolvedEntry` = `memory_id, resolution_summary, status, resolved_by_party`. All existing output
fields stay.

Rules (all in one `tenant_tx`, cursor read in the same tx):
- `cursor` = current max event id for the map, always returned.
- `since=N`: candidate members = members touched by events with id > N. If none → `nodes=[]`, `resolved=[]`,
  same cursor (never "everything"). `since=None` → all members are candidates.
- `include="open"`: `nodes` = candidates with status open; candidates that are settled go to `resolved` (compact).
  `include="all"`: `nodes` = all candidates with their status (+resolution_summary); `resolved = []`.
- `depth="summary"`: `content` longer than 200 chars → `content[:200] + "…"` (single U+2026 char), `truncated=True`;
  ≤200 chars → unchanged, `truncated=False`. `depth="full"` → whole content, `truncated=False`.
  Put the truncation in a small pure helper with a `SUMMARY_CONTENT_CHARS = 200` constant (unit-testable).
- `edges`: with `since=None` all internal edges as today; with `since` set, only internal edges with at least one
  endpoint among the candidate ids (empty when nothing changed).
- Update `TOOL_DESCRIPTIONS["mindmap_get"]` to describe the levers, cursor, `resolved`, and the new open_loops
  semantics (e.g. "resume cheaply: mindmap_get(map_key, since=<last cursor>)").
- Briefly update `skills/mindmap-driver/SKILL.md` (settle a branch with mindmap_resolve; resume with since/cursor)
  and add `mindmap_resolve` to the tool table in `docs/mindmap-v1-build-design.md`. Don't change other tools'
  behaviour (mindmap_review may stay as is).

## Tests (add new files; do NOT modify existing tests)
- `tests/unit/test_mindmap_resolve_unit.py` (or similar): input validation (summary required, 1..500, bad
  disposition/party rejected, extra fields forbidden, defaults), MindmapGetInput defaults + `since` ge=0, the
  truncation helper at 199/200/201 chars and `full`.
- `tests/integration/test_mindmap_resolve_e2e.py` using the `test_mindmap_e2e.py` fixture pattern (UUID-suffixed
  tenants/teams, stub embedder). Cover at least:
  - resolve with resolver → status resolved, `resolves-under` edge resolver→node in `memory_references`, event
    row `resolve`, cursor advanced; dropped → `dropped-under`; no resolver → settled, no edge.
  - node of another map (same tenant) → -32602, that node's status unchanged, no edge, no event; unknown map →
    -32602; root node → -32602; resolver not in this map → -32602 and nothing changed.
  - archived map → -32602 `map_not_live`.
  - open_loops: includes owner- and model-responsible open nodes, excludes nodes without responsible_party, and
    excludes a node after it's resolved; a bare `mindmap_link` with `resolves-under` does NOT settle anything.
  - get defaults: settled branch absent from `nodes`, present in `resolved` with summary/status/party; include=all
    shows every member with status; long content truncated with `…` + `truncated=True`, full returns whole.
  - since: `since=cursor` immediately → no nodes, same cursor; after a write_node → only that node; after a
    resolve → that node appears in `resolved` (include=open) only.
  - migration CHECK: direct UPDATE setting status='bogus' fails.

## Verify & report
Run: `alembic upgrade head`; `pytest -q -p no:cacheprovider tests/unit tests/integration` (also run `pytest -q`
full suite); `ruff check src tests`; `mypy`. Compare failures against a baseline run of the full suite on the
untouched tree (`git stash` is fine, or note which failures are pre-existing) and report exact pass/fail counts and
the names of any failing tests, stating which are pre-existing.
