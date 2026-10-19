# Work order 1 — Mind-map branch status + `mindmap_resolve` + cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth where this order is
silent), `skills/mindmap-driver/SKILL.md`, `src/mem_mcp/mindmap/service.py`,
`src/mem_mcp/mcp/tools/mindmap_*.py`, `src/mem_mcp/mcp/tools/_mindmap_common.py`,
`src/mem_mcp/teams/references.py`, `alembic/versions/0038_2026_06_19_mindmap_tables.py`,
`tests/integration/test_mindmap_e2e.py` (fixture pattern for DB-backed tool tests).

## Problem
Every `mindmap_get` returns every node in full. There is no per-branch settlement (only
`mindmap_close` settles the whole map), so `open_loops` only ever grows. We need (A) a stored
per-node status, (B) a `mindmap_resolve` tool, (C) an `open_loops` fix, (D) cheap reads on `mindmap_get`.

## A. Schema — new migration
New file `alembic/versions/0044_2026_10_16_mindmap_branch_status.py`,
`revision = "0044_mindmap_branch_status"`, `down_revision = "0043_backfill_personal_teams"`
(verify that exact string in 0043). Docstring explaining *why* (see Problem). `op.execute(sa.text(...))`.
Add to **`memory_map_membership`** (status is per map member):
- `status TEXT NOT NULL DEFAULT 'open'` with CHECK `status IN ('open','resolved','dropped')`
- `resolution_summary TEXT NULL` with CHECK `char_length(resolution_summary) BETWEEN 1 AND 500` (NULL ok)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL` with CHECK `resolved_by_party IN ('owner','model')`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: `status = 'open'` ⇒ summary/party/resolved_at/resolved_by_memory_id all NULL;
  `status IN ('resolved','dropped')` ⇒ summary, party, resolved_at NOT NULL.
Name all constraints explicitly; `downgrade()` drops them + the columns. Existing rows default to `open`.
Run `alembic upgrade head` and confirm it applies (and that `alembic downgrade -1` then `upgrade head`
round-trips).

Status is the ONLY source of truth for "settled". Never infer it from
`memory_references.reference_kind` (unvalidated free text); an edge alone never settles a branch.

## Service layer (`src/mem_mcp/mindmap/service.py`) — all SQL goes here
- `fetch_members(...)`: also return `status, resolution_summary, resolved_by_memory_id,
  resolved_by_party, resolved_at`.
- New `get_membership(conn, *, memory_id, root_memory_id, tenant_id)` → row or None (only if the node is a
  member of THAT map; explicit tenant filter). Should also return the node's memory `team_id`
  (join `memories`, `deleted_at IS NULL`).
- New `set_branch_status(conn, *, memory_id, root_memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)` — UPDATE … `resolved_at = now()`, scoped by memory_id AND
  root_memory_id AND tenant_id.
- `log_event(...)`: make it return the new event id (`RETURNING id`) — existing callers ignoring the return
  value must keep working.
- New `current_cursor(conn, *, root_memory_id) -> int`: `COALESCE(MAX(id), 0)` from `memory_map_events`
  for that map.
- New `memory_ids_touched_since(conn, *, root_memory_id, since: int) -> set[UUID]`: distinct non-null
  `memory_id` of this map's events with `id > since`.
- Keep the tenant-scope linter clean (`tests/unit/test_lint_tenant_scope.py`) — add explicit
  `tenant_id` filters on per-tenant tables or follow the exempt convention used elsewhere in this file.
- Domain-level exceptions only (no `JsonRpcError` in service).

## B. New tool `mindmap_resolve`
Module `src/mem_mcp/mcp/tools/mindmap_resolve.py`, classes `MindmapResolveTool` (name `"mindmap_resolve"`,
`required_scope = "memory.write"`), `MindmapResolveInput`, `MindmapResolveOutput`. Register in
`src/mem_mcp/main.py` next to the other mindmap tools; add a `TOOL_DESCRIPTIONS["mindmap_resolve"]` entry in
`mcp/tool_descriptions.py` in house style (what it does, "Call when: …", "Do not call for: …" — e.g. not
for settling the whole map (use mindmap_close), Example → …). Also update the `mindmap_get` description
for the new levers/cursor and the `open_loops` semantics.

Input (`model_config = ConfigDict(extra="forbid")`):
| field | type | notes |
|---|---|---|
| `map_key` | str, 1..64 | |
| `node_id` | UUID | branch to settle |
| `disposition` | `Literal["resolved","dropped"]` | default `"resolved"` |
| `resolution_summary` | str, 1..500, **required** | |
| `resolved_by_memory_id` | UUID \| None | default None |
| `resolved_by_party` | `Literal["owner","model"]` | default `"model"` |
| `team_id` | UUID \| None | |

Output: `node_id: UUID`, `status: str`, `resolution_summary: str`, `cursor: int`, `request_id: str`.

Behaviour:
1. Resolve team + map root like the other tools. Unknown map → `JsonRpcError(-32602, "map not found",
   data={"errors": [{"path": "map_key"}]})`.
2. Lifecycle (design doc: archived = no-reopen, closed maps don't accept changes): map not `live` →
   `JsonRpcError(-32602, ..., data={"code": "map_not_live"})`, nothing changed.
3. `node_id` not a member of THIS map (unknown id, deleted, or a member of a different map) →
   `JsonRpcError(-32602, "node not found in map", data={"errors": [{"path": "node_id"}]})`, nothing changed.
   Same error for all these cases (opaque). The map's root node (node_role `root`) is the map itself, not a
   branch → also -32602 (`path: node_id`, message telling to use mindmap_close).
4. `resolved_by_memory_id`, if given: must not equal `node_id` (-32602, path `resolved_by_memory_id`), and
   must exist & be accessible to the caller — check with `resolve_reference_target(sys_conn,
   target_uuid=..., caller_user_id=ctx.tenant_id)` inside `system_tx`, exactly as `mindmap_link` does its
   access check; on `ReferenceTargetNotFoundError` → `JsonRpcError(-32602, "reference target not found or
   not accessible", data={"code": "memory_not_accessible"})` from exc. Do this validation BEFORE any write.
5. In ONE `tenant_tx`: (re-)verify map live + membership (do the checks in this tx so they can't race),
   `set_branch_status(...)`; if a resolving node is named, write the edge via
   `teams.references.insert_reference` (the same function `mindmap_link` uses) with
   `source_memory_id = resolved_by_memory_id`, `target_memory_id = node_id`,
   `target_team_id = <settled node's team_id>`, `reference_kind = "resolves-under"` for disposition
   `resolved` and `"dropped-under"` for `dropped` (design-doc reference-kind vocabulary; put these in a
   module-level constant mapping). No resolving node → no edge, branch still settled. Then
   `log_event(event="resolve", actor=<resolved_by_party>, memory_id=node_id, payload={"disposition", 
   "resolved_by_memory_id" (str or None), "reference_kind" (or None)})` — never put the summary text
   itself in logs/structlog (event payload may carry its length). The returned event id is the `cursor`.
6. Re-resolving an already-settled node is allowed (overwrites status/summary; logs a new event).
   Does not bump `writes_since_review`.

## C. `open_loops` fix (`mindmap_get`)
Whose-turn definition (design doc, spec f5e52f08): `open_loops` = members whose
`metadata.responsible_party == "owner"` **and** `status == "open"`. A resolved/dropped node is never an
open loop. `open_loops` is always computed over the whole map (it is just ids), regardless of `since`/
`include`.

## D. Cheap reads on `mindmap_get`
New inputs on `MindmapGetInput` (defaults = cheap): `since: int | None = Field(default=None, ge=0)`,
`include: Literal["open","all"] = "open"`, `depth: Literal["summary","full"] = "summary"`.
(Only add `extra="forbid"` if the existing model/tests tolerate it — do not break existing tests.)

New output: `cursor: int`; `resolved: list[MindmapResolvedEntry]` where entry =
`memory_id: UUID, resolution_summary: str, status: str, resolved_by_party: str`.
`MindmapNode` gains `status: str` and `truncated: bool`. All existing output fields stay.

Read everything (map row, members, edges, cursor, touched-set) inside the one `tenant_tx`.
- `cursor` = current max event id for this map (0 if none).
- `since` given: candidate members = members whose id is in `memory_ids_touched_since(since)`. If nothing
  changed (empty set, incl. `since >= cursor`) → `nodes == []`, `resolved == []`, `edges == []`, same
  cursor. NEVER fall back to "everything". `since=None` → all members are candidates.
- `include="open"`: `nodes` = candidates with status `open`; candidates with status resolved/dropped go to
  `resolved` (one compact entry each). `include="all"`: `nodes` = all candidates each with its `status`;
  `resolved` = `[]`.
- `depth="summary"`: if `len(content) > 200` → `content[:200] + "…"` (single U+2026), `truncated=True`;
  else content as-is, `truncated=False`. `depth="full"`: whole content, `truncated=False`. Put 200 in a
  module-level constant.
- `edges`: only internal edges with at least one endpoint among the returned `nodes`/`resolved` ids
  (with `since=None, include="all"` this is all internal edges, as before).
- Update module docstrings to explain the levers and why (cost should scale with open work).

## Docs
- `docs/mindmap-v1-build-design.md`: add `mindmap_resolve` to the tool table, the membership status
  columns to the schema sketch, and the `mindmap_get` levers/cursor; keep it short.
- `skills/mindmap-driver/SKILL.md`: tell the driver to settle branches with `mindmap_resolve` and resume
  with `mindmap_get(since=<last cursor>)`.

## Tests (add new files; do not modify existing tests)
- `tests/unit/test_mindmap_resolve_models.py` (DB-free): input defaults/validation (summary required,
  1..500; disposition/party literals; since ≥ 0), truncation helper (exactly 200 → unchanged,
  201 → 200 chars + "…" & truncated, full → whole).
- `tests/integration/test_mindmap_branch_status.py` (DB-backed through the tools, fixture style from
  `test_mindmap_e2e.py`, UUID-suffixed names): at least
  - resolve with resolving node → status resolved, `resolves-under` edge from resolver to node in
    `memory_references`, event logged, cursor advanced; dropped → `dropped-under`; no resolver → no edge.
  - node of another map / random uuid / root → -32602, DB unchanged; unknown map → -32602;
    archived map → -32602 `map_not_live`; inaccessible/nonexistent resolver → -32602, DB unchanged.
  - `open_loops`: owner-turn node appears, disappears after resolve; model-turn node never appears.
  - `mindmap_get` defaults: settled branch absent from `nodes`, present in `resolved`; long content
    truncated; `include="all"` shows statuses; `depth="full"` whole.
  - `since`: get → cursor c; get(since=c) → no nodes, same cursor; write a node → get(since=c) returns only
    that node and a bigger cursor; resolve → get(since=c2) returns that node in `resolved`.
  - migration CHECKs: direct UPDATE with bad status / party rejected.

## Acceptance / verification — report exact outputs
1. `alembic upgrade head` (and downgrade -1 / upgrade head round-trip).
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_branch_status.py tests/integration/test_mindmap_e2e.py`
3. Full suite `pytest -q -p no:cacheprovider` BEFORE you change anything (stash-free: just run it first)
   and AFTER — report the list of failing tests in both runs so new failures can be ruled out.
4. `ruff check src tests`, `ruff format --check` on changed files, `mypy` — clean for new/changed code.
