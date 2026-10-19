# Work order 1 — Mind-map branch status, `mindmap_resolve`, `open_loops` fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md`, `src/mem_mcp/mindmap/service.py`,
`src/mem_mcp/mcp/tools/mindmap_{get,link,write_node,open}.py`, `src/mem_mcp/mcp/tool_descriptions.py`,
`alembic/versions/0038_2026_06_19_mindmap_tables.py`, `tests/integration/test_mindmap_e2e.py` (fixture pattern).

## Why
`mindmap_get` returns every node in full on every call, so settled branches stay in the agent's context
forever. We need (A) a stored per-branch status, (B) a tool to settle one branch without closing the map,
(C) `open_loops` that drops settled branches, (D) cheap incremental/compact reads.

## A. Migration (new file)
`alembic/versions/0044_2026_10_16_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`. Docstring explaining why (above). `op.execute(sa.text(...))`.
Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL CHECK (resolution_summary IS NULL OR char_length(resolution_summary) BETWEEN 1 AND 500)`
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL CHECK (resolved_by_party IS NULL OR resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- A consistency CHECK (named constraint): `status = 'open'` ⇔ (`resolution_summary`, `resolved_by_party`,
  `resolved_at` all NULL); settled ⇒ those three NOT NULL. (`resolved_by_memory_id` may be NULL when settled.)
- Index on `memory_map_events(root_memory_id, id)` for cursor queries.
Existing rows default to `open`. Provide `downgrade()` dropping these. Run `alembic upgrade head` and
also verify `alembic downgrade -1 && alembic upgrade head` works.

Status is the ONLY source of truth for "settled". Never infer it from `memory_references.reference_kind`;
an edge alone (e.g. via `mindmap_link ... resolves-under`) never settles a branch.

## B. Service layer (`src/mem_mcp/mindmap/service.py`) — all SQL here, explicit `tenant_id` filters
(the tenant-scope linter `tests/unit/test_lint_tenant_scope.py` must stay green).
- Constants in `mindmap/__init__.py`: `BRANCH_STATUSES = ("open","resolved","dropped")`,
  `SUMMARY_CONTENT_CHARS = 200`, and `DISPOSITION_REFERENCE_KINDS = {"resolved": "resolves-under",
  "dropped": "dropped-under"}` (from the design doc's reference-kind vocabulary).
- Domain exception `MapNodeNotFoundError(Exception)` (no JsonRpcError in the service).
- `fetch_members` additionally returns `status, resolution_summary, resolved_by_memory_id,
  resolved_by_party, resolved_at`.
- `settle_branch(conn, *, root_memory_id, tenant_id, memory_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party) -> dict`: `UPDATE memory_map_membership SET ... resolved_at=now()
  WHERE memory_id=$ AND root_memory_id=$ AND tenant_id=$ AND node_role <> 'root' RETURNING ...`;
  zero rows → raise `MapNodeNotFoundError` (covers: node in another map, unknown node, root node).
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int`: `COALESCE(MAX(id), 0)` of
  `memory_map_events` for the map.
- `touched_since(conn, *, root_memory_id, tenant_id, since) -> set[UUID]`: memory ids touched by events
  with `id > since` for this map: the event's `memory_id`, plus for `link` events the `payload->>'target'`
  (cast safely). Caller intersects with member ids.

## C. New tool `src/mem_mcp/mcp/tools/mindmap_resolve.py`
Classes `MindmapResolveTool` (name `mindmap_resolve`, scope `memory.write`), `MindmapResolveInput`
(`model_config = ConfigDict(extra="forbid")`), `MindmapResolveOutput`. Register in `src/mem_mcp/main.py`
next to the other mindmap tools; add a `TOOL_DESCRIPTIONS["mindmap_resolve"]` entry in house style
(what it does, "Call when:", "Do not call for:" — e.g. not for closing the whole map → `mindmap_close`;
not for just drawing an edge → `mindmap_link` — and an Example).

Input: `map_key: str (1..64)`, `node_id: UUID`, `disposition: Literal["resolved","dropped"] = "resolved"`,
`resolution_summary: str (min_length=1, max_length=500)` required, `resolved_by_memory_id: UUID | None = None`,
`resolved_by_party: Literal["owner","model"] = "model"`, `team_id: UUID | None = None`.
Output: `node_id, status, resolution_summary, cursor: int, request_id`.

Flow:
1. If `resolved_by_memory_id == node_id` → -32602 (`errors: [{"path": "resolved_by_memory_id", ...}]`).
2. If `resolved_by_memory_id` given: the edge is **source = resolving node, target = settled node**.
   Mirror `mindmap_link`: in a `system_tx`, call `resolve_reference_target(sys_conn, target_uuid=node_id,
   caller_user_id=ctx.tenant_id)` (gives the target's team_id for `insert_reference`), and also
   access-check the resolving node the same way (`resolve_reference_target` on `resolved_by_memory_id`).
   Either failing → -32602 `data={"code": "memory_not_accessible"}` (opaque), nothing written.
3. One `tenant_tx`: `resolve_team_id`, `resolve_map_root` (None → -32602 "map not found",
   `errors:[{"path":"map_key"}]`), `get_map_row`; state != 'live' → -32602 `data={"code": "map_not_live"}`
   (no-reopen lifecycle: archived maps are frozen). Then `service.settle_branch` (MapNodeNotFoundError →
   -32602 `errors:[{"path":"node_id","message":"node is not a member of this map"}]`, `from e`).
   If resolving node given: `insert_reference(conn, source_memory_id=resolved_by, target_memory_id=node_id,
   target_team_id=<from resolve_reference_target>, reference_kind=DISPOSITION_REFERENCE_KINDS[disposition])`
   — the same function `mindmap_link` uses. Then `service.log_event(event="resolve",
   actor=resolved_by_party, memory_id=node_id, payload={"disposition", "resolved_by", "reference_kind"})`.
   Then `cursor = current_cursor(...)` in the same tx. Any failure rolls everything back (single tx).
4. Re-settling an already settled branch is allowed (overwrites settlement, logs a new event).

## D. `mindmap_get` changes (`src/mem_mcp/mcp/tools/mindmap_get.py`)
New inputs (defaults = cheap): `since: int | None = Field(default=None, ge=0)`,
`include: Literal["open","all"] = "open"`, `depth: Literal["summary","full"] = "summary"`.
`MindmapNode` gains `status: str` and `truncated: bool`. New model `MindmapResolvedBranch`
(`memory_id, resolution_summary, status, resolved_by_party`). `MindmapGetOutput` gains
`cursor: int` and `resolved: list[MindmapResolvedBranch]`; all existing fields stay.

Rules:
- Read members, edges, cursor (and touched set) in the **same** tenant_tx.
- `since` given → candidate set = members whose id is in `touched_since(since)`; if nothing touched,
  `nodes == []` and `resolved == []` and cursor unchanged (never fall back to "everything"). `since=None` →
  all members.
- `include="open"`: `nodes` = candidates with status `open`; candidates with status resolved/dropped go to
  `resolved` (compact entries). `include="all"`: all candidates in `nodes` (each with status); `resolved`
  still lists the settled candidates (compact) — fine either way, but be consistent and document.
- `depth="summary"`: content with `len > 200` → `content[:200] + "…"` (single U+2026), `truncated=True`;
  `len <= 200` unchanged, `truncated=False`. `depth="full"`: whole content, `truncated=False`.
- `edges`: with `since=None`, internal edges among all members (as today). With `since`, only edges having
  at least one endpoint in the touched candidate set.
- `open_loops` (fix): design-doc whose-turn definition — open nodes carry `metadata.responsible_party`
  ∈ {`owner`,`model`}; the open loops are members with `status == 'open'` and a `responsible_party` of
  `owner` **or** `model` (today only `owner` is counted — that is the bug). A resolved/dropped node is
  never an open loop. Compute it over **all** members regardless of `since`/`include` (it's the resume
  surface; a list of ids is cheap).
- Update the module docstring and `TOOL_DESCRIPTIONS["mindmap_get"]` for the new levers/fields and the
  corrected open_loops wording; also mention `mindmap_resolve` in `skills/mindmap-driver/SKILL.md`
  (short "Settle a branch" paragraph) and the reference-kind/event vocabulary in the design doc is fine to
  leave untouched.

## Tests (add new files; do not modify existing tests)
- `tests/integration/test_mindmap_branch_status.py` (DB-backed, through the tools, copy the fixture
  pattern of `test_mindmap_e2e.py`, UUID-suffixed names). Cover at least:
  resolve happy path (status stored in DB, summary, party, resolved_at, event row `resolve`, cursor
  advanced); resolve with resolving node → exactly one `memory_references` row source=resolver,
  target=node, kind `resolves-under`; `dropped` → `dropped-under`; no resolver → no edge but settled;
  node of a *different* map → -32602 and nothing changed in either map; unknown map → -32602;
  root node → -32602; archived map → -32602 `map_not_live`; self-resolve → -32602;
  `mindmap_link ... resolves-under` alone does NOT settle (status still open, still an open loop);
  open_loops includes owner and model nodes, excludes nodes without responsible_party, excludes settled;
  get defaults (`include=open`): settled node absent from `nodes`, present in `resolved` with fields;
  `include=all`: all nodes with statuses; `since=cursor` with no changes → `nodes==[]`, same cursor;
  after a write_node and a resolve, `since=<old cursor>` returns only those nodes; summary truncation at
  exactly 200 / 201 chars and long content (`len == 201`, ends with `…`, `truncated`); `depth=full`
  untruncated; `since` validation (`-1` rejected by the input model).
- A unit test for the input models (defaults, extra=forbid, summary length bounds).
- Migration check in a test: the CHECK constraints reject `status='bogus'` and an open row with a summary
  (insert/update via the maintenance/test DSN connection as other migration tests do, if there is a pattern;
  otherwise via `pg_pool`).

## Verify and report
1. `alembic upgrade head` (and downgrade -1 / upgrade head round-trip).
2. `pytest -q -p no:cacheprovider tests/integration/test_mindmap_branch_status.py tests/integration/test_mindmap_e2e.py <your unit tests>`
3. `pytest -q -p no:cacheprovider` full suite — report pass/fail counts, and compare the failing test list
   against `git stash`-free reasoning: list every failing test and state whether it involves files you
   touched (it should not).
4. `ruff check src tests`, `ruff format --check` on your files, `mypy`.
Report exact command outputs (counts) and the files changed.
