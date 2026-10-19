# Order 1 — Mind-map branch status, `mindmap_resolve`, open_loops fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth where this order is
silent), `src/mem_mcp/mindmap/service.py`, `src/mem_mcp/mcp/tools/mindmap_{get,link,write_node,close}.py`,
`src/mem_mcp/teams/references.py`, `alembic/versions/0038_2026_06_19_mindmap_tables.py`,
`tests/integration/test_mindmap_e2e.py` (fixture pattern to copy for new tests).

## Problem
`mindmap_get` returns every node in full every time; there is no per-branch settlement (only
`mindmap_close` for the whole map); `open_loops` never shrinks. Build per-branch stored status, a
`mindmap_resolve` tool, and cheap read levers on `mindmap_get`.

## A. Migration (new file)
`alembic/versions/0044_2026_10_16_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`, docstring explaining why (per-branch settlement; status
is stored state, never inferred from `memory_references.reference_kind`, which is unvalidated free text).
Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` (CHECK length ≤ 500 when not null is fine)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL CHECK (resolved_by_party IS NULL OR resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK: `status = 'open'` ⇔ (`resolution_summary`, `resolved_by_party`, `resolved_at` all NULL);
  settled ⇒ those three NOT NULL. (Name the constraints explicitly.)
Existing rows get `open` via the default. Provide `downgrade()` dropping the constraints/columns.
Run `alembic upgrade head` (then also verify `alembic downgrade -1 && alembic upgrade head` works).

## B. Service layer (`src/mem_mcp/mindmap/service.py`) — all SQL goes here
- `fetch_members`: also return `status, resolution_summary, resolved_by_memory_id, resolved_by_party, resolved_at`.
- `get_membership(conn, *, memory_id, root_memory_id, tenant_id) -> dict | None` — membership row only if
  the node belongs to THIS map (filter on root_memory_id and tenant_id).
- `settle_branch(conn, *, memory_id, root_memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)` — UPDATE ... SET ..., resolved_at = now() WHERE memory_id AND
  root_memory_id AND tenant_id. Re-settling an already-settled branch simply overwrites (no error).
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int` — `COALESCE(MAX(id), 0)` from
  `memory_map_events` for the map.
- `touched_since(conn, *, root_memory_id, tenant_id, since) -> set[UUID]` — distinct non-null `memory_id`
  of the map's events with `id > since`. ALSO include the target of `link` events (payload `target`)
  and of `resolve` events (the settled node is the event's memory_id; also include the resolving node if
  you put it in the payload) — i.e. a node is "touched" if any event after the cursor concerns it.
- `log_event` should return the new event id (`RETURNING id`) — keep existing callers working.
- Keep explicit `tenant_id = $n` filters (the tenant-scope linter `tests/unit/test_lint_tenant_scope.py`
  must stay green). No `JsonRpcError` in the service; raise own exceptions if needed.

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `mindmap_resolve`, `required_scope = "memory.write"`),
`MindmapResolveInput` (`model_config = ConfigDict(extra="forbid")`), `MindmapResolveOutput`.

Input fields:
- `map_key: str` (1..64)
- `node_id: UUID`
- `disposition: Literal["resolved","dropped"] = "resolved"`
- `resolution_summary: str` (min 1, max 500), required
- `resolved_by_memory_id: UUID | None = None`
- `resolved_by_party: Literal["owner","model"] = "model"`
- `team_id: UUID | None = None`

Output: `node_id: UUID`, `status: str`, `resolution_summary: str`, `cursor: int`, `request_id: str`.

Behaviour:
1. Resolve team + map root like the other mindmap tools. Unknown map → `JsonRpcError(-32602, "map not found",
   data={"errors":[{"path":"map_key"}]})`.
2. Map must be live (design doc: archived = no-reopen, closed maps are immutable) → otherwise
   `JsonRpcError(-32602, ..., data={"code":"map_not_live"})`, nothing changed.
3. `node_id` must be a member of THIS map (use `get_membership`); not a member (including a node owned by a
   different map, or nonexistent) → `JsonRpcError(-32602, "node is not a member of this map",
   data={"errors":[{"path":"node_id"}]})`, nothing changed. The root node (node_role 'root') cannot be
   settled — the root is the map itself; settling it is `mindmap_close` → same -32602 with path `node_id`.
4. `resolved_by_memory_id == node_id` → -32602 path `resolved_by_memory_id`.
5. If `resolved_by_memory_id` is given: write the edge **source = resolving node, target = settled node**
   through the same path `mindmap_link` uses (`teams.references.resolve_reference_target` in a
   `system_tx` for access/team resolution, then `insert_reference`). Edge kind from the design-doc
   vocabulary: `resolved` → `"resolves-under"`, `dropped` → `"dropped-under"` (module constants).
   Also check the resolving node is accessible to the caller (resolve it with
   `resolve_reference_target` too; not accessible → -32602 `data={"code":"memory_not_accessible"}`,
   opaque, nothing changed). Do the access lookups BEFORE the write transaction.
6. In ONE `tenant_tx`: `settle_branch` + (optional) `insert_reference` + `log_event(event="resolve",
   actor=<resolved_by_party>, memory_id=node_id, payload={"disposition", "resolved_by_memory_id",
   "reference_kind" (or null)})`. Do not put content/summary text in logs; the event payload may carry
   the disposition and ids. Return `cursor` = the id of that new event.
7. Don't bump `writes_since_review` (it's not a captured node) — state that choice in a comment.

Register in `src/mem_mcp/main.py` next to the other mindmap tools. Add a `"mindmap_resolve"` entry in
`src/mem_mcp/mcp/tool_descriptions.py` in house style ("Call when: …", "Do not call for: …" (e.g. closing
the whole map → mindmap_close; drawing an ordinary edge → mindmap_link), "Example: … → …").

## D. `mindmap_get` changes
New input fields on `MindmapGetInput` (add `model_config = ConfigDict(extra="forbid")` only if no existing
test passes extra keys — check; otherwise leave as-is):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

`MindmapNode` gains `status: str` and `truncated: bool`. New model `MindmapResolvedBranch` with
`memory_id: UUID, resolution_summary: str, status: str, resolved_by_party: str` (you may add
`resolved_by_memory_id: UUID | None`). `MindmapGetOutput` gains `cursor: int` and
`resolved: list[MindmapResolvedBranch]`. All existing output fields stay.

Semantics:
- `cursor` = `current_cursor` read in the same transaction as the members.
- `since` given → candidate members = only those in `touched_since(since)`. If nothing touched → `nodes=[]`,
  `resolved=[]`, same cursor. Never fall back to "everything". `since=None` → all members.
- `include="open"`: `nodes` = candidate members with status `open`; settled candidates go to `resolved`
  (compact entries). `include="all"`: every candidate in `nodes` (each with its `status`); `resolved` still
  lists the settled candidates' compact entries (harmless, consistent).
- `depth="summary"`: content longer than 200 chars → `content[:200] + "…"` (single U+2026 char),
  `truncated=True`; ≤200 chars → as-is, `truncated=False`. `depth="full"` → whole content, `truncated=False`.
  Put the 200 constant at module top (or in `mindmap/__init__.py`), e.g. `SUMMARY_CONTENT_CHARS = 200`.
- `edges`: only edges where both endpoints are among the returned `nodes` ids... NO — keep it simple and
  backward-compatible: edges among all map members when `since is None`; when `since` is given, only edges
  touching a candidate node. Document this in the docstring.
- `open_loops` (fix): per the design doc's whose-turn rule, an open loop is a member node that is still
  `open` AND carries `metadata.responsible_party` in (`owner`, `model`) — whoever's turn it is. Settled
  (resolved/dropped) nodes are NEVER open loops. Compute open_loops from ALL map members (not only the
  `since` candidates) — it is the resume surface and is cheap (ids only). Root excluded (it has no
  responsible_party anyway).
- Update the module docstring and `TOOL_DESCRIPTIONS["mindmap_get"]` (levers, cursor, resolved list,
  open_loops meaning).
- Also update `skills/mindmap-driver/SKILL.md` briefly: settle branches with `mindmap_resolve`; resume with
  `mindmap_get` (cheap defaults) and keep the cursor for `since`.

Check `mindmap_review` still works with the extra columns from `fetch_members` (it may build its own node
models — don't break it).

## E. Tests (new files only; do NOT modify existing tests)
- `tests/integration/test_mindmap_resolve.py` (DB-backed, through the tools, fixture copied from
  `test_mindmap_e2e.py`, UUID-suffixed names). Cover at least:
  - resolve with resolving node → status stored in DB, `resolves-under` edge row source=resolver,
    target=settled; event row `resolve` logged; output cursor equals max event id.
  - `dropped` disposition without resolver → status dropped, NO edge row, still settled.
  - unknown map → -32602; node of a DIFFERENT map (same tenant) → -32602 and that node's status unchanged;
    root node → -32602; archived map → -32602 `map_not_live`.
  - an edge alone (mindmap_link `resolves-under`) does NOT settle a branch (status stays open, still in open_loops).
  - open_loops: includes model-party and owner-party open nodes, excludes nodes without responsible_party,
    excludes settled nodes.
  - mindmap_get: default (open/summary) puts settled branches only in `resolved`; `include="all"` shows them
    in nodes with status; `since=cursor` with no change → `nodes==[]`, `resolved==[]`, same cursor; after a
    write_node, `since=old_cursor` returns just the new node and a larger cursor; after resolve,
    `since=old_cursor` returns the branch in `resolved`.
  - truncation: 200-char content untouched/`truncated=False`; 201-char content → length 201 with the last
    char `…` and first 200 equal to original, `truncated=True`; `depth="full"` returns whole.
- Unit tests (`tests/unit/test_mindmap_resolve_models.py` or similar): input validation (summary required,
  1..500, disposition literal, party literal, defaults), `mindmap_get` input defaults/validation
  (`since` ≥ 0), the truncation helper if you factor one out, tool registered in main / description present.

## Acceptance / verification — report exact results
1. `alembic upgrade head`; also downgrade -1 + upgrade head.
2. `pytest -q -p no:cacheprovider tests/integration/test_mindmap_e2e.py <your new tests>` — all green.
3. `pytest -q -p no:cacheprovider` full suite — report pass/fail counts and list failing test ids; confirm
   any failures are pre-existing (verify with `git stash` run of the same failing ids if unsure).
4. `ruff check src tests`, `ruff format --check` on changed files, `mypy` — clean for your files.
Report the files changed and any decision you made where this order was ambiguous.
