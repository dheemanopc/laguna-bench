# Work order 1 — Mind-map branch status, `mindmap_resolve`, `open_loops` fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth for mind-map rules),
`src/mem_mcp/mindmap/service.py`, `src/mem_mcp/mcp/tools/mindmap_*.py`, `_mindmap_common.py`,
`alembic/versions/0038_2026_06_19_mindmap_tables.py`, `tests/integration/test_mindmap_e2e.py`.

## Problem
`mindmap_get` returns every node in full every time; `mindmap_close` settles only the whole map, there is
no per-branch settlement, and `open_loops` never shrinks. Build per-branch status, a `mindmap_resolve`
tool, an `open_loops` fix, and cheap reads (cursor / include / depth) on `mindmap_get`.

## A. Migration — stored branch status
New file `alembic/versions/0044_2026_10_16_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`, docstring explaining *why* (as peers do), `op.execute(sa.text(...))`,
working `downgrade()` (drop constraints/columns). Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open'` with CHECK `status IN ('open','resolved','dropped')`
- `resolution_summary TEXT NULL` (CHECK length 1..500 when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL` with CHECK `resolved_by_party IN ('owner','model')`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: `status='open'` ⇔ `resolution_summary`, `resolved_by_party`, `resolved_at` all NULL
  (and for resolved/dropped, summary/party/resolved_at NOT NULL). Name all constraints explicitly.
Existing rows default to `open`. RLS/grants already cover the table (UPDATE policy exists). Run
`alembic upgrade head` (and verify `alembic downgrade -1` then `upgrade head` again works).

Status is the ONLY source of truth for "settled". Never infer it from `memory_references.reference_kind`;
an edge alone (e.g. a `mindmap_link` with `resolves-under`) must NOT settle a branch.

## B. Service layer (`src/mem_mcp/mindmap/service.py`) — all SQL here, tools thin
Add (names indicative, follow file style; explicit `tenant_id` filters for defence in depth / lint):
- Domain exceptions (no JsonRpcError in the service), e.g. `NodeNotInMapError`.
- `get_membership(conn, *, memory_id, root_memory_id, tenant_id) -> dict | None` — the row only if the
  node is a member of THIS map.
- `set_node_status(conn, *, memory_id, root_memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)` — UPDATE ... WHERE memory_id=$ AND root_memory_id=$ AND tenant_id=$,
  sets `resolved_at = now()`; returns whether a row was updated.
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int` — `COALESCE(MAX(id), 0)` from
  `memory_map_events` for the map.
- Make `log_event` return the new event id (`RETURNING id`) — existing callers can ignore it.
- `touched_since(conn, *, root_memory_id, tenant_id, since) -> set[UUID]` — node ids touched by map events
  with `id > since`: the event's `memory_id`, plus `payload->>'target'` when present (link events), plus
  `payload->>'resolved_by_memory_id'` if you put it in the resolve payload. Ignore NULLs.
- `fetch_members` must also return `status, resolution_summary, resolved_by_memory_id, resolved_by_party,
  resolved_at`.

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `mindmap_resolve`, `required_scope = "memory.write"`),
`MindmapResolveInput`, `MindmapResolveOutput`. Register in `src/mem_mcp/main.py` next to the other mindmap
tools; add a `TOOL_DESCRIPTIONS["mindmap_resolve"]` entry in house style (what it does, "Call when:",
"Do not call for:" — e.g. closing the whole map → `mindmap_close`; just drawing an edge → `mindmap_link` —
"Example: ... → ...").

Input (`model_config = ConfigDict(extra="forbid")`):
| field | type | notes |
|---|---|---|
| `map_key` | str, 1..64 | |
| `node_id` | UUID | branch to settle |
| `disposition` | `Literal["resolved","dropped"]` | default `"resolved"` |
| `resolution_summary` | str 1..500, **required** | |
| `resolved_by_memory_id` | UUID \| None | default None |
| `resolved_by_party` | `Literal["owner","model"]` | default `"model"` |
| `team_id` | UUID \| None | |

Output: `node_id`, `status`, `resolution_summary`, `cursor: int`, `request_id`.

Behaviour:
1. Resolve team + map like the other tools. Unknown map → `JsonRpcError(-32602, "map not found",
   data={"errors":[{"path":"map_key"}]})`.
2. Map not live (archived) → `JsonRpcError(-32602, ..., data={"code":"map_not_live"})` (no-reopen rule,
   same as `mindmap_write_node`). Nothing changed.
3. `node_id` not a member of THIS map (including: member of a different map, non-existent, other tenant)
   → `-32602` with `data={"errors":[{"path":"node_id", "message": ...}]}`; identical response for all of
   those cases (opaque). Nothing changed. The map's root node is not a branch → also -32602 path `node_id`.
4. If `resolved_by_memory_id` is given: it must differ from `node_id` (else -32602 path
   `resolved_by_memory_id`), and resolve/access-check it exactly as `mindmap_link` does
   (`resolve_reference_target` in a `system_tx`, mapping `ReferenceTargetNotFoundError` to
   `-32602 data={"code":"memory_not_accessible"}`). Do this check BEFORE any write.
5. In ONE `tenant_tx`: update the membership status/settlement fields; if a resolving node was named,
   insert the edge via `teams.references.insert_reference` (the same function `mindmap_link` uses) with
   **source = resolving node, target = settled node**, `reference_kind = "resolves-under"` for
   `resolved` and `"dropped-under"` for `dropped` (design-doc vocabulary; put these in constants, e.g.
   in `mindmap/__init__.py`); then `log_event(event="resolve" or "drop", actor=resolved_by_party,
   memory_id=node_id, payload={"status":..., "resolved_by_memory_id": str|None, "reference_kind": ...|None})`.
   Do not put the summary text in logs (structlog); in the event payload is fine but not necessary.
   The returned `cursor` = the id of that event (i.e. the cursor advanced).
   For the edge's `target_team_id`, use the settled node's team (resolve it with `resolve_reference_target`
   too, or read it from memories within the tx — your call, keep it in the service/references layer).
6. Re-settling an already settled node is allowed (overwrites status/summary, logs a new event).
   No resolving node → no edge, branch still settled.
7. Must not bump `writes_since_review` (it's not a capture). (If you think the design doc says otherwise,
   tell me in your report.)

## D. `open_loops` fix (in `mindmap_get`)
Design doc whose-turn rule (`f5e52f08`): "open nodes carry `metadata.responsible_party` (`owner`|`model`);
`mindmap_get` returns the open set as the resume surface". So `open_loops` = ids of member nodes whose
stored `status == 'open'` AND whose `metadata.responsible_party` is `"owner"` or `"model"`. A
resolved/dropped node is never an open loop. `open_loops` always reflects the whole map (not filtered by
`since`/`include`) — it is just ids, cheap. Update the `mindmap_get` description and module docstring
accordingly (they currently say owner-only).

## E. Cheap reads on `mindmap_get`
New `MindmapGetInput` fields (keep existing ones; add `extra="forbid"` only if the existing tests still
pass with it — otherwise leave config as is):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

`MindmapNode` gains `status: str` and `truncated: bool`. New model `MindmapResolvedEntry` with
`memory_id, resolution_summary, status, resolved_by_party`. `MindmapGetOutput` gains `cursor: int` and
`resolved: list[MindmapResolvedEntry]`. All existing output fields stay.

Algorithm (one `tenant_tx`):
1. Read `cursor` FIRST (before fetching members), so a concurrent write can only be re-seen, never missed.
2. Fetch members. If `since` is not None: keep only members in `touched_since(since)`; if nothing
   touched → no nodes, empty `resolved`, no edges, and `cursor` unchanged (== since when nothing happened).
   Never fall back to "everything".
3. `include="open"`: `nodes` = selected members with status `open`; settled selected members go to
   `resolved` (compact entries). `include="all"`: every selected member in `nodes` (with its status);
   `resolved` may also be populated with the settled ones — choose: populate `resolved` only for
   `include="open"`, empty for `"all"`. Document in the description.
4. `depth="summary"`: content longer than 200 chars → `content[:200] + "…"` (single U+2026), `truncated=True`;
   ≤200 → unchanged, `truncated=False`. `depth="full"` → whole content, `truncated=False`. Put 200 in a
   constant (e.g. `SUMMARY_CONTENT_CHARS` in `mindmap/__init__.py`).
5. `edges`: internal edges restricted to those with at least one endpoint in the returned `nodes`
   (so a `since` read with no changes returns no edges).
6. `cursor` in output; `open_loops` as in D.

Update the `mindmap_get` description (levers, cursor workflow: "keep the cursor, pass it as since next
time", defaults are cheap; use `include="all", depth="full"` for the full picture e.g. before close).
Also update `skills/mindmap-driver/SKILL.md` briefly: settle branches with `mindmap_resolve`, resume
with `mindmap_get(since=<cursor>)`.

## Tests (add new files; do NOT modify existing tests)
- `tests/unit/test_mindmap_resolve_get_models.py` (DB-free): input validation (summary required, 1..500;
  disposition/party/include/depth literals; since ≥ 0; defaults cheap), truncation helper edge cases
  (exactly 200 → not truncated; 201 → 200 chars + "…", truncated; full depth).
- `tests/integration/test_mindmap_resolve.py` (DB-backed through the tools; copy the fixture style of
  `test_mindmap_e2e.py`, UUID-suffixed names). Cover at least:
  - resolve with resolving node → status stored, edge `resolves-under` source=resolver target=node exists,
    event logged, cursor advanced; `dropped` → `dropped-under` edge; no resolver → no edge, still settled.
  - node of a different map / random UUID / root → -32602, nothing changed (status still open, no edge,
    no new event).
  - archived map (after `mindmap_close`) → -32602 `map_not_live`.
  - unknown map → -32602.
  - `mindmap_link` with `resolves-under` alone does NOT settle (node still open, still in open_loops).
  - open_loops: owner- and model-party open nodes listed; settled ones not; nodes without responsible_party not.
  - get defaults: settled branch absent from `nodes`, present in `resolved` with summary/status/party;
    `include="all"` shows every member with status; truncation in summary vs full.
  - `since=<cursor>` with no changes → `nodes == []`, same cursor; after a write → only the new node;
    after a resolve → the settled node shows up in `resolved` (include=open).
  - DB CHECK rejects an invalid status value (direct SQL).
- Run: `alembic upgrade head`, then `pytest -q -p no:cacheprovider tests/unit tests/integration` BEFORE
  and AFTER your change (stash or note baseline failures first) and report exact pass/fail counts and the
  names of any failures, making clear none are new. Also `ruff check src tests`, `ruff format --check`
  on touched files, `mypy` (project config), and confirm
  `tests/unit/test_lint_tenant_scope.py` passes.

## Report back
Files changed, design choices you made where this order was ambiguous, exact test/lint command outputs
(counts), and anything uncertain.
