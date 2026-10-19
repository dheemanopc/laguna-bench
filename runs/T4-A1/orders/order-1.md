# Work order 1 — Mind-map branch status, `mindmap_resolve`, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth for map rules),
`src/mem_mcp/mindmap/service.py`, `src/mem_mcp/mcp/tools/mindmap_{get,link,close,write_node,open}.py`,
`src/mem_mcp/mcp/tools/_mindmap_common.py`, `src/mem_mcp/teams/references.py`,
`alembic/versions/0038_2026_06_19_mindmap_tables.py`, `tests/integration/test_mindmap_e2e.py`.

## Problem
`mindmap_get` returns every node in full every time; there is no per-branch status (only `mindmap_close`
settles the whole map), so `open_loops` only grows. Build: (A) stored per-node branch status,
(B) a `mindmap_resolve` tool, (C) an `open_loops` fix, (D) cheap reads on `mindmap_get`.

Layering is mandatory: all SQL in `mem_mcp/mindmap/service.py` (service raises its own exception types,
never `JsonRpcError`), tools thin, `tenant_tx`, explicit `WHERE tenant_id = $n` on per-tenant tables
(the linter `tools/lint_tenant_scope.py` / `tests/unit/test_lint_tenant_scope.py` must stay green).

## A. Migration (new file)
`alembic/versions/0044_2026_10_15_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`, docstring explaining why, `op.execute(sa.text(...))`,
working `downgrade()`. Add to **`memory_map_membership`** (status is per map member):
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` with CHECK `char_length(resolution_summary) BETWEEN 1 AND 500` (when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL CHECK (resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- a consistency CHECK: `status = 'open'` ⇒ resolution_summary, resolved_by_party, resolved_at and
  resolved_by_memory_id are all NULL; `status <> 'open'` ⇒ resolution_summary, resolved_by_party,
  resolved_at NOT NULL. Name all constraints explicitly.
- Existing rows default to `open`. Index on `memory_map_events(root_memory_id, id)` for cursor reads.
Run `alembic upgrade head` (and verify `alembic downgrade -1` then `upgrade head` again works).

Status is the ONLY source of truth for "settled". Never infer it from `memory_references.reference_kind`.

## B. Service additions (`mindmap/service.py`)
- `log_event(...)` returns the new event `id` (`RETURNING id`, int). Existing callers may ignore it.
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int`: `COALESCE(MAX(id), 0)` of this map's events.
- `fetch_members` also returns `status, resolution_summary, resolved_by_memory_id, resolved_by_party, resolved_at`.
- `fetch_member(conn, *, root_memory_id, memory_id, tenant_id) -> dict | None` — membership row of
  `memory_id` **in this map** (joined to memories for team_id, deleted_at IS NULL), else None.
- `settle_member(conn, *, root_memory_id, memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)` — `UPDATE ... SET ..., resolved_at = now() WHERE memory_id=$
  AND root_memory_id=$ AND tenant_id=$ AND status='open'`; raise a service exception (e.g.
  `NodeNotOpenError`) if 0 rows updated.
- `touched_since(conn, *, root_memory_id, tenant_id, since: int) -> set[UUID]`: distinct non-null
  `memory_id` of this map's events with `id > since`.
- Define service exceptions in the service module (e.g. `MapNodeNotFoundError`, `NodeNotOpenError`).

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `mindmap_resolve`, scope `memory.write`), `MindmapResolveInput`
(`model_config = ConfigDict(extra="forbid")`), `MindmapResolveOutput`. Register in `main.py` with the other
mindmap tools; add a `TOOL_DESCRIPTIONS["mindmap_resolve"]` entry in the house style (what it does,
"Call when:", "Do not call for:", example). Fix any test that enumerates the registered tool set/
descriptions only if it's a registry-completeness test that is designed to be updated — otherwise tell me.

Input:
| field | type | notes |
|---|---|---|
| `map_key` | str (1..64) | |
| `node_id` | UUID | branch node to settle |
| `disposition` | `Literal["resolved","dropped"]` | default `"resolved"` |
| `resolution_summary` | str, min_length=1, max_length=500, **required** | |
| `resolved_by_memory_id` | UUID \| None | default None |
| `resolved_by_party` | `Literal["owner","model"]` | default `"model"` |
| `team_id` | UUID \| None | |

Output: `node_id: UUID`, `status: str` (new status), `resolution_summary: str`, `cursor: int`, `request_id: str`.

Behaviour (all errors `JsonRpcError(-32602, ...)` and nothing changed):
1. Resolve team + map like the other tools. Unknown map → `-32602 "map not found"`,
   `data={"errors": [{"path": "map_key"}]}`.
2. Map state must be `live` (design doc: archived maps are no-reopen / immutable) →
   else `-32602`, `data={"code": "map_not_live"}`.
3. `node_id` must be a member of **this** map (a node of another map, or any non-member, is refused) →
   `-32602`, `data={"errors": [{"path": "node_id", "message": "not a member of this map"}]}`.
   The root node (node_role `root`) cannot be resolved (settling the root = closing the map → use
   `mindmap_close`); same -32602 with path `node_id`.
4. Node already settled (status not `open`) → `-32602`, `data={"code": "node_not_open"}`.
5. If `resolved_by_memory_id` is given: must differ from `node_id` (else -32602 path
   `resolved_by_memory_id`) and must be a memory the caller can access — check it with
   `resolve_reference_target` (same as mindmap_link, in a `system_tx`, before the write tx); on
   `ReferenceTargetNotFoundError` → `-32602 "reference target not found or not accessible"`,
   `data={"code": "memory_not_accessible"}` (opaque).
6. In ONE `tenant_tx`: `settle_member(...)`; if a resolving node was given, record the edge with
   `teams.references.insert_reference` (the same function `mindmap_link` uses):
   `source_memory_id = resolved_by_memory_id`, `target_memory_id = node_id`,
   `target_team_id = <settled node's team_id>`, `reference_kind = "resolves-under"` for `resolved`,
   `"dropped-under"` for `dropped` (the design doc's reference-kind vocabulary). No resolving node → no
   edge, branch still settled. Then `log_event(event="resolve" or "drop", actor=resolved_by_party,
   memory_id=node_id, payload={"disposition", "resolved_by_memory_id", "reference_kind" or None})` and
   return its id as `cursor`. Do the map/membership/state checks inside this same transaction (lock the
   membership row, e.g. via the conditional UPDATE) so concurrent resolves can't both win.

## D. `mindmap_get` changes
New `MindmapGetInput` fields (keep existing ones; the model currently has no `extra="forbid"`, leave it):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

`MindmapNode` gains `status: str` and `truncated: bool`. New model `MindmapResolvedEntry` with
`memory_id: UUID`, `resolution_summary: str`, `status: str`, `resolved_by_party: str`.
`MindmapGetOutput` gains `cursor: int` and `resolved: list[MindmapResolvedEntry]` (default empty). All
existing output fields stay.

Semantics (read everything in one tenant_tx; read the cursor in that same tx):
- `cursor` = `current_cursor` for this map, always returned.
- Candidate set = all members; if `since` is not None, restrict to members in `touched_since(since)`.
  If nothing changed → `nodes == []`, `resolved == []`, `edges == []`, and `cursor == since`-equivalent
  current cursor. Never "everything".
- `include="open"`: `nodes` = candidates with status `open`; candidates with status resolved/dropped go to
  `resolved` (compact entries). `include="all"`: every candidate in `nodes` (with its status);
  `resolved` empty.
- `depth="summary"`: if `len(content) > 200` → `content[:200] + "…"` (single U+2026 char), `truncated=True`;
  else content as-is, `truncated=False`. `depth="full"`: whole content, `truncated=False`.
  Put the 200 limit in a module constant (e.g. `SUMMARY_CHARS = 200` in `mem_mcp/mindmap/__init__.py`
  next to `SOFT_NODE_CHARS`).
- `edges`: internal edges (as today) restricted to those with at least one endpoint in the returned `nodes`.
- `open_loops` (fix): design doc whose-turn rule — "open nodes carry `metadata.responsible_party`
  (`owner`|`model`); `mindmap_get` returns the open set as the resume surface". So an open loop is a member
  whose stored `status == 'open'` AND whose `metadata.responsible_party` is `owner` or `model`. A
  resolved/dropped node is never an open loop. Compute it over ALL members (not limited by `since`/
  `include`) — it is a cheap list of ids and is the resume surface. Update the module docstring.
- Update `TOOL_DESCRIPTIONS["mindmap_get"]` to describe the levers (cheap defaults, cursor/since flow,
  include="all", depth="full") and mention `mindmap_resolve`.
- Also briefly document the new tool + status in `skills/mindmap-driver/SKILL.md` and add a short
  "Branch status & cheap reads" section to `docs/mindmap-v1-build-design.md` (tool table row for
  `mindmap_resolve`, the new columns).

## Tests (add new files; do NOT modify existing tests)
- `tests/unit/test_mindmap_resolve_models.py` (DB-free): input validation (summary required, 1..500,
  disposition/party literals, extra fields rejected, defaults), `mindmap_get` input defaults
  (`since=None, include="open", depth="summary"`, `since=-1` rejected), the truncation helper
  (exactly 200 → unchanged/false, 201 → 200 chars + "…" / true).
- `tests/integration/test_mindmap_resolve_e2e.py` (DB-backed, through the tools, fixture modelled on
  `test_mindmap_e2e.py`, UUID-suffixed names). Cover at least:
  - resolve with resolving node → status `resolved`, membership columns set, exactly one
    `memory_references` row (resolver→settled, `resolves-under`), a `resolve` event, cursor advanced;
  - drop without resolving node → status `dropped`, no edge row created;
  - node of a different map (by id) → -32602, nothing changed in either map; unknown map → -32602;
    root → -32602; already-settled → -32602 `node_not_open`; archived map → -32602 `map_not_live`;
    inaccessible/nonexistent resolver → -32602 `memory_not_accessible` and node still `open`;
  - an edge `resolves-under` drawn via `mindmap_link` alone does NOT settle the node (still in nodes /
    open_loops);
  - `open_loops` includes owner- and model-responsible open nodes, excludes settled ones and nodes without
    responsible_party;
  - `mindmap_get` default: settled nodes in `resolved` not `nodes`; `include="all"` gives all with status;
    long content truncated in summary, whole in full; every node has `status`;
  - `since`: read cursor c; with no changes `since=c` → no nodes, cursor == c; write a node / resolve a
    node → cursor > c and `since=c` returns only the touched node(s).
- The CHECK constraints: a direct SQL insert/update with an invalid status / open-with-summary is rejected.

## Verify & report
Run `alembic upgrade head`, then `pytest -q -p no:cacheprovider tests/unit tests/integration`, plus
`ruff check src tests`, `ruff format --check` on files you touched, `mypy`. Also run the full `pytest -q`
and compare against a baseline run on a clean stash (or `git stash` the change, run, unstash) so you can
list exactly which failures are pre-existing vs new. Report: files changed, exact test command lines with
pass/fail counts, the list of pre-existing failures, and anything you were unsure about.
