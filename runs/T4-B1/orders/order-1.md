# Work order 1 — Mind-map branch status, `mindmap_resolve`, `open_loops` fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (esp. "Reference-kind vocabulary",
"Whose-turn", lifecycle/no-reopen), `src/mem_mcp/mindmap/service.py`, `src/mem_mcp/mindmap/__init__.py`,
`src/mem_mcp/mcp/tools/mindmap_{get,link,write_node,close,open}.py`, `_mindmap_common.py`,
`src/mem_mcp/teams/references.py` (`resolve_reference_target`, `insert_reference`),
`tests/integration/test_mindmap_e2e.py` (fixture pattern), `alembic/versions/0038_*.py` (peer migration).

## Problem
`mindmap_get` returns every node in full every time, and there is no per-branch settlement:
`mindmap_close` settles the whole map only, and `open_loops` only grows. Build per-branch status
(stored), a `mindmap_resolve` tool, fix `open_loops`, and add cheap-read levers to `mindmap_get`.

## A. Migration (stored status)
New file `alembic/versions/0044_2026_10_15_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`; docstring explaining why (per existing style); SQL via
`op.execute(sa.text(...))`; working `downgrade()`.
Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open'` with CHECK `status IN ('open','resolved','dropped')`
- `resolution_summary TEXT NULL` (CHECK length 1..500 when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL` with CHECK `resolved_by_party IN ('owner','model')`
- `resolved_at TIMESTAMPTZ NULL`
- a consistency CHECK: `status='open'` ⇒ resolution_summary, resolved_by_party, resolved_at are all NULL
  (resolved_by_memory_id NULL too); `status<>'open'` ⇒ resolution_summary, resolved_by_party, resolved_at NOT NULL.
Name the constraints explicitly. Existing rows default to `open`. RLS/grants already cover the table.
Run `alembic upgrade head` against the test DB (and verify downgrade -1 / upgrade head round-trips).

**Status is the source of truth for "settled". Never infer it from `memory_references.reference_kind`;
an edge alone (e.g. a `mindmap_link` with `resolves-under`) never settles a branch.**

## B. Service layer (`mindmap/service.py`) — all SQL lives here
- Domain exceptions (no JsonRpcError in the service), e.g. `NodeNotInMapError`, `BranchAlreadySettledError`
  (define in service.py or `mindmap/__init__.py`, follow repo style).
- `fetch_members` also returns `status, resolution_summary, resolved_by_memory_id, resolved_by_party, resolved_at`.
- `get_member(conn, *, root_memory_id, memory_id, tenant_id)` → membership row or None (must filter by
  root_memory_id AND tenant_id — a node of a *different* map is "not a member").
- `settle_branch(conn, *, root_memory_id, memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party)` → `UPDATE memory_map_membership SET ..., resolved_at=now()
  WHERE memory_id=$ AND root_memory_id=$ AND tenant_id=$ AND status='open' RETURNING ...`.
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int` = `COALESCE(MAX(id),0)` from `memory_map_events`.
- `touched_since(conn, *, root_memory_id, tenant_id, since, upto) -> set[UUID]`: memory_ids of events with
  `since < id <= upto` (non-null memory_id), PLUS for `link`/`resolve`/`drop` events the related node id in
  the payload (`target` for link; resolving node for resolve) when present — so edges touch both ends.
- `log_event` should return the new event id (`RETURNING id`) — keep existing callers working.
- Keep the tenant-scope linter clean (`tests/unit/test_lint_tenant_scope.py`): explicit `tenant_id` filters.
- Put new constants (`BRANCH_STATUSES`, `SUMMARY_CONTENT_CHARS = 200`, disposition→edge-kind map
  `{"resolved": "resolves-under", "dropped": "dropped-under"}`) in `mindmap/__init__.py`.

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `mindmap_resolve`, `required_scope="memory.write"`),
`MindmapResolveInput` (`model_config = ConfigDict(extra="forbid")`), `MindmapResolveOutput`.

Input:
- `map_key: str` (1..64)
- `node_id: UUID`
- `disposition: Literal["resolved","dropped"] = "resolved"`
- `resolution_summary: str` (min_length=1, max_length=500), required
- `resolved_by_memory_id: UUID | None = None`
- `resolved_by_party: Literal["owner","model"] = "model"`
- `team_id: UUID | None = None`

Output: `node_id`, `status`, `resolution_summary`, `cursor: int`, `request_id`.

Behaviour (all errors are `JsonRpcError(-32602, ...)`, nothing written on error):
1. Resolve team + map like the other tools. Unknown map → `-32602 "map not found"`,
   `data={"errors":[{"path":"map_key"}]}`.
2. Map archived → `-32602`, `data={"code":"map_not_live"}` (no-reopen lifecycle: archived maps are frozen).
3. `node_id` not a member of THIS map (including a member of another map, or a nonexistent id) →
   `-32602`, `data={"errors":[{"path":"node_id","message":"node is not a member of this map"}]}` —
   identical for "other map" and "does not exist" (opaque).
4. `node_id` is the map's root (node_role `root`) → -32602 path `node_id` (the root is the map itself; settle
   it with `mindmap_close`).
5. Already settled (status != open) → `-32602`, `data={"code":"branch_already_settled"}`.
6. `resolved_by_memory_id == node_id` → -32602 path `resolved_by_memory_id`.
7. If `resolved_by_memory_id` given: check it is accessible via `resolve_reference_target` (under
   `system_tx`, exactly as `mindmap_link` does) → on `ReferenceTargetNotFoundError` → -32602
   `data={"code":"memory_not_accessible"}`. Also resolve the settled node (the edge *target*) the same way to
   get its `team_id` for `insert_reference`.
8. In ONE `tenant_tx`: re-check map live (the state check should be inside this tx, e.g. `SELECT ... FOR UPDATE`
   on the map row or equivalent), `settle_branch` (if it returns nothing → branch_already_settled / not member
   error, tx rolls back), then if a resolving node was named `insert_reference(source=resolved_by_memory_id,
   target=node_id, target_team_id=<settled node's team>, reference_kind="resolves-under" for resolved /
   "dropped-under" for dropped)` — the same `teams.references.insert_reference` that `mindmap_link` uses;
   then `log_event(event="resolve" or "drop", actor=resolved_by_party, memory_id=node_id,
   payload={"disposition", "resolved_by_memory_id", "reference_kind" (or None), "summary_chars"})` — do not
   put the summary text itself in logs (structlog); in the event payload it's fine to omit it too.
   No resolving node → no edge, branch still settled.
   Return `cursor` = id of the event just logged (== current cursor).
9. Does NOT bump `writes_since_review`.

Register in `src/mem_mcp/main.py` (import + tool list next to the other mindmap tools) and add a
`"mindmap_resolve"` entry in `mcp/tool_descriptions.py` in the house style (what it does, "Call when: …",
"Do not call for: …" (e.g. closing the whole map → mindmap_close; drawing a plain edge → mindmap_link),
"Example: … → …"). If any test enumerates registered tools/descriptions, make sure it stays green (don't
edit existing tests; if one hard-codes the tool list and would break, report it to me instead).
Also update `skills/mindmap-driver/SKILL.md` briefly (settle a branch with mindmap_resolve; resume with
`mindmap_get(since=<cursor>)`).

## D. `open_loops` fix (mindmap_get)
Design doc whose-turn (`f5e52f08`): open nodes carry `metadata.responsible_party` ∈ {`owner`,`model`}; the
open set is the resume surface. So `open_loops` = member ids with `responsible_party in ("owner","model")`
AND `status == "open"` (root excluded unless it has a responsible_party — it normally doesn't). A
resolved/dropped node is never an open loop. Compute `open_loops` over ALL members regardless of
`since`/`include` (it's ids only, cheap) — ordered by added_at.

## E. Cheap reads on `mindmap_get`
New `MindmapGetInput` fields (keep `extra` behaviour as currently — do not break existing callers):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

`MindmapNode` gains `status: str` and `truncated: bool`. New model `MindmapResolvedBranch`
(`memory_id, resolution_summary, status, resolved_by_party`). `MindmapGetOutput` gains
`cursor: int` and `resolved: list[MindmapResolvedBranch]`. All existing output fields stay.

Semantics (single `tenant_tx`; read the cursor FIRST, then everything else, and bound the `since` query by
`id <= cursor` so nothing is skipped by a concurrent write):
- `cursor` = current max event id for the map (0 if none). Always returned.
- `since=None`: candidate set = all members. `since=N`: candidate set = members touched by events with
  `N < id <= cursor`. If none → `nodes=[]`, `resolved=[]`, `edges=[]`, `cursor` unchanged. Never "everything".
  `since` greater than the cursor → treat as nothing changed.
- `include="open"`: `nodes` = candidates with status `open` (the root has status open and is included like
  any open member); candidates with status resolved/dropped go into `resolved` as compact entries (no content).
  `include="all"`: every candidate in `nodes` (each with its `status`); `resolved` = [] in that mode
  (settled info visible via node status). Document this choice in the description.
- `depth="summary"`: if `len(content) > 200` → `content[:200] + "…"` (single U+2026 char) and `truncated=True`;
  else content as-is, `truncated=False`. `depth="full"`: whole content, `truncated=False`.
- `edges`: with `since=None` unchanged (internal edges among all members). With `since=N`: only internal
  edges with at least one endpoint in the candidate set.
- Update `mindmap_get`'s module docstring and its `TOOL_DESCRIPTIONS` entry (levers, defaults, cursor
  workflow: "keep cursor, next time pass since=cursor").
- `mindmap_review` must keep returning the full structure (don't change its behaviour); if it reuses
  `fetch_members` that's fine.

## F. Tests (add new files; do NOT modify existing tests)
- `tests/unit/test_mindmap_resolve_models.py` (DB-free): input validation (summary required/1..500,
  disposition/party literals, extra forbidden), `MindmapGetInput` defaults (`since=None, include="open",
  depth="summary"`), `since<0` rejected, truncation helper (200 → not truncated; 201 → 200 chars + "…",
  truncated; full depth), tool name/scope/registration in main's tool list + description present.
- `tests/integration/test_mindmap_branch_status.py` (real DB, reuse the e2e fixture pattern with
  UUID-suffixed tenants) covering at least:
  1. resolve with resolving node → membership status/summary/party/resolved_by/resolved_at stored;
     `memory_references` row (source=resolver, target=node, kind `resolves-under`); event logged; cursor advanced.
  2. drop without resolving node → status dropped, NO edge; with resolving node → `dropped-under`.
  3. node of a different map (same tenant) → -32602, nothing changed in either map; random uuid → same error.
  4. archived map → -32602 `map_not_live`; unknown map → -32602; root node → -32602; already settled → -32602.
  5. `mindmap_link(... reference_kind="resolves-under")` alone does NOT settle the target (status still open,
     still in open_loops).
  6. `open_loops`: model- and owner-party nodes are open loops; after resolve they're not; nodes without
     responsible_party are not.
  7. `mindmap_get` defaults: settled branch absent from `nodes`, present in `resolved` with summary/status/party;
     `include="all"` returns all with statuses; long content truncated with `…` + `truncated=True` in summary,
     whole in full; exactly-200-char content untouched.
  8. `since`: get → cursor c; get(since=c) → no nodes, same cursor; write a node → get(since=c) returns only
     that node and a larger cursor; resolve a node → get(since=c2) returns it under `resolved`.
  9. Migration CHECKs: direct UPDATE setting `status='bogus'` or `resolved` without summary is rejected.

## Verification (report exact commands + results)
1. `alembic upgrade head` (and downgrade -1 / upgrade head round-trip).
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_branch_status.py tests/integration/test_mindmap_e2e.py`
3. Full suite `pytest -q -p no:cacheprovider` — report pass/fail counts and list every failing test; compare
   against `git stash`-free baseline reasoning: tell me which failures are pre-existing (e.g. run the failing
   ones on a clean checkout via `git worktree` if needed, or explain why they're unrelated).
4. `ruff check src tests`, `ruff format --check` on the files you touched, `mypy` — report results.
Do not commit.
