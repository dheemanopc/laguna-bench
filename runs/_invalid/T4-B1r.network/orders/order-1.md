# Work order 1 — Mind-map branch status, `mindmap_resolve`, open_loops fix, cheap `mindmap_get` reads

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth where this order is silent),
`docs/adr/0007-*.md`, `docs/adr/0008-*.md`, `skills/mindmap-driver/SKILL.md`, `src/mem_mcp/mindmap/service.py`,
all `src/mem_mcp/mcp/tools/mindmap_*.py`, `_mindmap_common.py`, `teams/references.py`,
`alembic/versions/0038_*` (map tables) and the latest migration (`0043_*`) for the revision chain,
and `tests/integration/test_mindmap_e2e.py` (fixture pattern).

## Problem
`mindmap_get` returns every node in full every time; there is no per-branch settlement (only `mindmap_close`
for the whole map), so `open_loops` only ever grows. Build per-branch status + cheap reads.

## A. Stored branch status (new Alembic migration)
- New file `alembic/versions/0044_YYYY_MM_DD_mindmap_branch_status.py` (today's date 2026_10_16 is fine),
  `revision = "0044_mindmap_branch_status"` style matching existing files, `down_revision` = the 0043 revision id
  (copy it exactly). Docstring explains why. `op.execute(sa.text(...))`, real `downgrade()`.
- Add columns to `memory_map_membership`:
  - `status text not null default 'open'` with CHECK `status IN ('open','resolved','dropped')`
  - `resolution_summary text null` (CHECK length ≤ 500 when not null is fine)
  - `resolved_by_memory_id uuid null` (FK to memories(id) ON DELETE SET NULL is acceptable, or no FK — your call; justify)
  - `resolved_by_party text null` with CHECK `resolved_by_party IS NULL OR resolved_by_party IN ('owner','model')`
  - `resolved_at timestamptz null`
  - A consistency CHECK: when status='open' the settlement fields are NULL; when status in (resolved, dropped),
    `resolution_summary`, `resolved_by_party`, `resolved_at` are NOT NULL.
  - Name the constraints explicitly. Existing RLS/grants on the table already cover new columns (verify).
- Apply with `alembic upgrade head`; also verify `alembic downgrade -1` then `upgrade head` works.
- Status is the ONLY source of truth for "settled". Never infer it from `memory_references.reference_kind`;
  an edge alone (e.g. a `resolves-under` link via `mindmap_link`) never settles a branch.

## B. New tool `mindmap_resolve`
Module `src/mem_mcp/mcp/tools/mindmap_resolve.py`: `MindmapResolveTool` (name `mindmap_resolve`,
`required_scope="memory.write"`), `MindmapResolveInput` (`ConfigDict(extra="forbid")`), `MindmapResolveOutput`.
Register in `src/mem_mcp/main.py` next to the other mindmap tools; add a `TOOL_DESCRIPTIONS["mindmap_resolve"]`
entry in house style ("Call when: … / Do not call for: … / Example: … → …"). Check whether any test asserts the
exact registered tool set/count or description keys and make sure that still passes (don't edit existing tests;
if one hard-codes the list, report it).

Input:
| field | type | notes |
|---|---|---|
| `map_key` | str, 1..64 | |
| `node_id` | UUID | branch to settle |
| `disposition` | `Literal["resolved","dropped"]` | default `"resolved"` |
| `resolution_summary` | str 1..500, required | |
| `resolved_by_memory_id` | UUID \| None | default None |
| `resolved_by_party` | `Literal["owner","model"]` | default `"model"` |
| `team_id` | UUID \| None | |

Output: `node_id`, `status`, `resolution_summary`, `cursor: int`, `request_id`.

Behaviour (all in ONE `tenant_tx` for the writes):
1. Resolve team + map root exactly like the other tools. Unknown map → `JsonRpcError(-32602, "map not found", data={"errors":[{"path":"map_key"}]})`.
2. Lifecycle: map must be `live`; archived → `JsonRpcError(-32602, ..., data={"code":"map_not_live"})` (same as close/write_node; no-reopen). Nothing changes.
3. `node_id` must be a member of THIS map (membership row with `root_memory_id = root` and tenant scoping, node not soft-deleted). Otherwise `-32602` with `data={"errors":[{"path":"node_id", ...}]}` and nothing changes — a node of another map (or a non-member) must not be settable. Also refuse settling the map's root node itself (`node_id == root`) with -32602 path `node_id`.
4. If `resolved_by_memory_id` given: must not equal `node_id` (-32602, path `resolved_by_memory_id`); access-check it
   the same way `mindmap_link` checks its target (`resolve_reference_target` in a `system_tx`, mapping
   `ReferenceTargetNotFoundError` to `-32602` `data={"code":"memory_not_accessible"}`) — do this check BEFORE any write.
   Then write the edge with `teams.references.insert_reference` (the same path mindmap_link uses):
   source = resolving node, target = settled node (`node_id`; its team_id from the members/memories row),
   `reference_kind` = `"resolves-under"` for disposition resolved, `"dropped-under"` for dropped (design doc vocabulary).
   No resolving node → no edge, branch still settled.
5. Update the membership row (new service function, e.g. `service.set_branch_status(...)`, SQL lives in
   `mindmap/service.py`, filtered by memory_id AND root_memory_id AND tenant_id) setting status, summary,
   resolved_by_memory_id, resolved_by_party, resolved_at=now(). Re-settling an already settled branch is allowed
   (overwrites; idempotent).
6. `service.log_event(..., event="resolve" (or "drop" for dropped — pick one scheme and document it), actor=resolved_by_party,
   memory_id=node_id, payload={"disposition":..., "resolved_by_memory_id": str|None, "reference_kind": str|None})`.
7. Return `cursor` = current cursor after the event (see D) — read inside the same transaction.
8. Domain functions raise their own exceptions or return None; the tool maps to `JsonRpcError` (CONVENTIONS).
   Audit: follow what other mindmap write tools do (if they don't audit, don't add a new AuditAction).

## C. `open_loops` fix (mindmap_get)
Design doc "Whose-turn (f5e52f08)": open nodes carry `metadata.responsible_party` (`owner`|`model`) and the
open set is the resume surface. New rule: `open_loops` = member nodes with stored `status == 'open'` AND
`metadata.responsible_party in ('owner','model')`. A resolved/dropped node is NEVER an open loop. Compute it from
all members regardless of `since`/`include`/`depth` (it is a list of UUIDs; cheap). Update the module docstring and
the `mindmap_get` tool description accordingly (and the SKILL.md capture paragraph + a short "Resolve" section
describing `mindmap_resolve` and the cheap-read levers).

## D. Cheap reads on `mindmap_get`
Add to `MindmapGetInput` (defaults = cheap):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

Output additions (keep every existing field):
- `cursor: int` — `COALESCE(MAX(id), 0)` of `memory_map_events` for this map (service function, tenant-scoped).
  Every read returns it; any write_node/link-with-map_key/review/resolve advances it.
- `resolved: list[MindmapResolvedEntry]` where entry = `memory_id`, `resolution_summary`, `status`, `resolved_by_party`.
- `MindmapNode` gains `status: str` and `truncated: bool`.

Semantics:
- `since=c`: only nodes "touched" by map events with `id > c` for this map. Touched = the event's `memory_id`, plus
  any member ids referenced in the event payload (`target`, `resolved_by_memory_id`). Only map members are ever
  returned. If nothing changed → `nodes == []`, `resolved == []`, and the same cursor (never fall back to "everything").
  `since=None` → all members.
- `include="open"`: `nodes` holds only status=open members; settled members (within the since-filter) go to
  `resolved` as compact entries (no content). `include="all"`: every (since-filtered) member in `nodes` with its
  `status`; `resolved` may also be populated with settled ones or empty — make it populated consistently and document.
  (Recommended: `resolved` always lists the since-filtered settled members in both modes.)
- `depth="summary"`: content longer than 200 chars → `content[:200] + "…"` (single U+2026 char), `truncated=True`;
  ≤200 chars → unchanged, `truncated=False`. `depth="full"` → whole content, `truncated=False`. Define
  `SUMMARY_CONTENT_CHARS = 200` as a module constant.
- `edges`: when `since` is None, unchanged (all internal edges). When `since` is given, return only internal edges
  with at least one endpoint in the touched set.
- Keep the root node in `nodes` as today (it is open by default).
- SQL changes (fetch_members selecting the new columns; cursor; touched ids since cursor) go in `mindmap/service.py`
  with explicit tenant filters (the repo lint `tools/lint_tenant_scope.py` must stay clean).

## Tests (add new files; do NOT modify existing tests)
- `tests/unit/test_mindmap_resolve_models.py` (or similar, DB-free): input validation (defaults, extra forbidden,
  summary length 0/501 rejected, bad disposition/party rejected, `since` < 0 rejected), truncation helper at
  199/200/201 chars and `depth="full"`.
- `tests/integration/test_mindmap_branch_status.py` (DB-backed through the tools, copy fixture pattern from
  `test_mindmap_e2e.py`, UUID-suffixed names). Cover at least:
  - resolve with resolving node → status stored, `resolves-under` edge source=resolver target=settled in
    `memory_references`, event row logged, cursor advanced; dropped → `dropped-under` edge.
  - resolve without resolving node → settled, no new edge.
  - node from a different map / unknown map / non-member → -32602 and DB unchanged.
  - archived map → -32602 `map_not_live`.
  - `mindmap_link` with `resolves-under` alone does NOT settle the branch (status stays open, still in open_loops).
  - open_loops: includes open owner- and model-responsible nodes, excludes resolved/dropped ones.
  - `since`: unchanged → no nodes + same cursor; after one write only that node returned; after resolve, the node
    appears (in `resolved` for include=open).
  - include open vs all; depth summary vs full; existing fields still present.
- Run: `alembic upgrade head`, then `pytest -q -p no:cacheprovider tests/unit tests/integration` and also the full
  `pytest -q -p no:cacheprovider`. Record the set of failures BEFORE your change (run once first, e.g. `git stash`
  is not needed — just run the suite before editing) and AFTER; report both lists so I can confirm no new failures.
- `ruff check src tests`, `ruff format --check` on touched files, `mypy` — report results.

## Report back
Files changed, design choices you made where this order gave latitude, exact test commands + pass/fail counts
(before vs after failure lists), lint/mypy output.
