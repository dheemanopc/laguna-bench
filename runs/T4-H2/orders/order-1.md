# Work order 1 — Mind-map branch status, `mindmap_resolve`, open_loops fix, cheap reads on `mindmap_get`

Read first: `CONVENTIONS.md`, `docs/mindmap-v1-build-design.md` (source of truth where this order is silent),
`src/mem_mcp/mindmap/service.py`, `src/mem_mcp/mcp/tools/mindmap_*.py`, `_mindmap_common.py`,
`src/mem_mcp/teams/references.py`, `alembic/versions/0038_2026_06_19_mindmap_tables.py`,
`tests/integration/test_mindmap_e2e.py` (fixture pattern for DB-backed tool tests).

Problem: `mindmap_get` returns every node in full every time; there's no per-branch settle; `open_loops`
only grows. Build the following.

## A. Stored branch status — new Alembic migration

New file `alembic/versions/0044_2026_10_15_mindmap_branch_status.py`, `revision = "0044_mindmap_branch_status"`,
`down_revision = "0043_backfill_personal_teams"`, docstring explaining *why* (as peers do), SQL via
`op.execute(sa.text(...))`, real `downgrade()` dropping what was added.

Add to `memory_map_membership`:
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dropped'))`
- `resolution_summary TEXT NULL` (CHECK length ≤ 500 when not null)
- `resolved_by_memory_id UUID NULL REFERENCES memories(id) ON DELETE SET NULL`
- `resolved_by_party TEXT NULL CHECK (resolved_by_party IS NULL OR resolved_by_party IN ('owner','model'))`
- `resolved_at TIMESTAMPTZ NULL`
- a consistency CHECK: when `status='open'` then resolution_summary, resolved_by_party, resolved_at are all NULL
  (resolved_by_memory_id NULL too); when status is resolved/dropped then resolution_summary, resolved_by_party
  and resolved_at are NOT NULL.
Name the constraints explicitly so downgrade can drop them. Existing rows default to `open`.
Run `alembic upgrade head` (and verify downgrade -1 / upgrade head round-trips).

Status is the ONLY source of truth for "is this branch settled". Never infer it from
`memory_references.reference_kind` — an edge alone (e.g. a `resolves-under` link via `mindmap_link`) never settles a branch.

## B. Service layer (`src/mem_mcp/mindmap/service.py`) — all SQL here, tools stay thin

Add (names are suggestions; keep explicit `tenant_id` filters on every per-tenant query — the
`tools/lint_tenant_scope.py` linter / `tests/unit/test_lint_tenant_scope.py` must stay green):
- `fetch_membership(conn, *, memory_id, root_memory_id, tenant_id) -> dict | None` — the membership row of
  `memory_id` **in this map** (None if not a member of this map).
- `settle_branch(conn, *, memory_id, root_memory_id, tenant_id, status, resolution_summary,
  resolved_by_memory_id, resolved_by_party) -> dict` — UPDATE … SET status, summary, resolver, party,
  `resolved_at = now()` WHERE memory_id/root/tenant match AND `status = 'open'` RETURNING row.
- `current_cursor(conn, *, root_memory_id, tenant_id) -> int` — `COALESCE(MAX(id), 0)` of
  `memory_map_events` for this map.
- `fetch_touched_since(conn, *, root_memory_id, tenant_id, since) -> set[UUID]` — distinct non-null
  `memory_id` of this map's events with `id > since`.
- `log_event` should return the inserted event id (`RETURNING id`) so a writer can report the new cursor
  (keep existing callers working).
- `fetch_members` must also return `status, resolution_summary, resolved_by_memory_id, resolved_by_party, resolved_at`.
- Domain-level exception types if useful (e.g. `BranchNotFoundError`, `BranchAlreadySettledError`) —
  service never imports `JsonRpcError`.

## C. New tool `mindmap_resolve`

Module `src/mem_mcp/mcp/tools/mindmap_resolve.py`: `MindmapResolveTool` (name `mindmap_resolve`,
`required_scope = "memory.write"`), `MindmapResolveInput`, `MindmapResolveOutput`. Register in
`src/mem_mcp/main.py` next to the other mindmap tools; add a `TOOL_DESCRIPTIONS["mindmap_resolve"]` entry in
`src/mem_mcp/mcp/tool_descriptions.py` in house style (what it does, "Call when: …", "Do not call for: …",
"Example: … → …"; mention it settles ONE branch without closing the map, that the summary is what cheap reads
show instead of the branch, and that `mindmap_close` is for the whole map).

Input (`model_config = ConfigDict(extra="forbid")`):
| field | type | notes |
|---|---|---|
| `map_key` | str, 1..64 | |
| `node_id` | UUID | branch node to settle |
| `disposition` | `Literal["resolved","dropped"]` | default `"resolved"` |
| `resolution_summary` | str, 1..500, **required** | |
| `resolved_by_memory_id` | UUID \| None | default None |
| `resolved_by_party` | `Literal["owner","model"]` | default `"model"` |
| `team_id` | UUID \| None | |

Output: `node_id: UUID`, `status: str` (new status), `resolution_summary: str`, `cursor: int`, `request_id: str`.

Behaviour:
1. Resolve team + map root exactly like the other tools. Unknown map → `JsonRpcError(-32602, "map not found",
   data={"errors":[{"path":"map_key"}]})`.
2. Lifecycle: map not `live` (archived) → `JsonRpcError(-32602, ..., data={"code": "map_not_live"})`
   (same as write_node/close). Nothing changed.
3. `node_id` not a member of **this** map (unknown id, or member of another map, or another tenant's) →
   `-32602` with `data={"errors":[{"path":"node_id", "message": ...}]}`; nothing changed. Must not be able to
   settle a node of a different map by id. The map's own root node (node_role `root`) cannot be settled
   either (→ same -32602 on `node_id`) — settling the whole map is `mindmap_close`.
4. Node already resolved/dropped → `-32602` with `data={"code": "branch_already_settled"}`; nothing changed.
5. `resolved_by_memory_id`: if given, must not equal `node_id` (-32602, path `resolved_by_memory_id`), and must be
   resolvable/accessible via `resolve_reference_target` in a `system_tx` exactly as `mindmap_link` does
   (opaque `-32602`, `data={"code":"memory_not_accessible"}` on failure).
6. In ONE `tenant_tx`: settle the branch (service), and when a resolving node is named, insert the edge via
   `teams.references.insert_reference` (same call shape as `mindmap_link`): **source = resolving node,
   target = settled node**, `reference_kind` = `"resolves-under"` for disposition `resolved`, `"dropped-under"`
   for `dropped` (design doc reference-kind vocabulary; put these as module constants / a mapping). Then
   `log_event` with `event` = `"resolve"` or `"drop"`, `actor` = the resolved_by_party, `memory_id` = node_id,
   payload `{disposition, resolved_by_memory_id (str or None), reference_kind (or None)}` — never log content
   or the summary text into structlog; the payload may carry ids only. The returned event id is the
   output `cursor`. If any step fails the whole thing rolls back. No resolving node → no edge, branch still settled.
   Do the map/membership/state checks inside that same transaction (lock the membership row, e.g.
   `SELECT … FOR UPDATE`, or rely on the `AND status='open'` UPDATE guard) so concurrent settles can't double-settle.
7. Audit if the peer mindmap tools audit (follow whatever `mindmap_close`/`write_node` do; don't invent an
   AuditAction unless needed).

## D. `mindmap_get` — cheap reads + open_loops fix

New input fields on `MindmapGetInput` (all default to the cheap setting):
- `since: int | None = Field(default=None, ge=0)`
- `include: Literal["open","all"] = "open"`
- `depth: Literal["summary","full"] = "summary"`

New/changed output:
- `MindmapGetOutput.cursor: int` — current cursor of the map's event log (`current_cursor`, read in the same
  transaction as the members). 0 if the map has no events.
- `MindmapNode` gains `status: str` and `truncated: bool` (and may carry resolution fields when settled — keep
  it simple: `status`, `truncated`; optional `resolution_summary: str | None = None` is fine).
- New output list `resolved: list[MindmapResolvedBranch]`, where `MindmapResolvedBranch` has `memory_id: UUID`,
  `resolution_summary: str`, `status: str`, `resolved_by_party: str`.
- All existing output fields stay.

Rules:
- `since=<cursor>`: restrict to members whose `memory_id` appears in this map's events with `id > since`
  (applies to both `nodes` and `resolved`). If nothing changed: `nodes == []`, `resolved == []`, same cursor —
  never "everything". `since=None` → no restriction. A `since` larger than the current cursor → nothing.
- `include="open"`: `nodes` contains only `status == 'open'` members; settled members go to `resolved`
  (compact entries). `include="all"`: every member in `nodes`, each with its `status`; `resolved` should be `[]`
  in that mode (all information is in `nodes`) — document this in the description.
- `depth="summary"`: if `len(content) > 200` → `content = content[:200] + "…"` (single U+2026 char; total 201
  chars) and `truncated=True`; otherwise unchanged, `truncated=False`. `depth="full"` → whole content,
  `truncated=False`. Put `200` as an UPPER_CASE constant (e.g. `SUMMARY_CONTENT_CHARS` in `mindmap/__init__.py`).
- `edges`: keep returning internal edges among the members that are returned in `nodes` + `resolved`? —
  NO: keep it simple and backward compatible: edges among *all* map members when `since is None`; when
  `since` is set, only edges where source or target is a touched member. (Edges are small.)
- `open_loops` (whose-turn, design doc `f5e52f08`: "open nodes carry `metadata.responsible_party`
  (`owner`|`model`); `mindmap_get` returns the open set as the resume surface"): the list of member ids that
  have `status == 'open'` AND `metadata.responsible_party` in `{"owner","model"}` — i.e. someone owes the next
  turn. Never the root, never a resolved/dropped node. Compute it over all members (independent of
  `include`/`depth`; when `since` is set, also restrict to touched members so the cheap delta read stays cheap).
  Update the module docstring and the `mindmap_get` tool description accordingly (describe since/include/depth,
  cursor, resolved, truncated, and the open_loops definition).
- Also update `skills/mindmap-driver/SKILL.md` briefly: settle branches with `mindmap_resolve`, resume with
  `mindmap_get(since=<last cursor>)`, ask for `depth="full"` only when needed.

## E. Tests (add new files; do NOT modify existing tests)

- `tests/unit/test_mindmap_resolve_models.py` (DB-free): input validation (summary required, 1..500,
  disposition/party literals, defaults, extra=forbid), get input defaults (`since=None, include="open",
  depth="summary"`, `since` ≥ 0), truncation helper boundaries (199/200/201 chars, exactly-200 not truncated,
  201 → 200 chars + "…", full depth not truncated). Make the truncation a small pure function so it's unit testable.
- `tests/integration/test_mindmap_resolve_e2e.py` (DB-backed via the tools, fixture modeled on
  `test_mindmap_e2e.py`, UUID-suffixed names, tolerate leftovers). Cover at least:
  - resolve with a resolving node → status `resolved` in DB, summary/party/resolved_at stored, edge
    `(source=resolver, target=node, kind='resolves-under')` exists, event `resolve` logged, output cursor ==
    new max event id and > prior cursor.
  - dropped without resolver → status `dropped`, no edge, event `drop`.
  - `dropped` with resolver → `dropped-under` edge.
  - unknown map; node of a *different* map; random uuid; root node → -32602, DB unchanged.
  - already-settled → -32602 `branch_already_settled`.
  - archived map (close it first) → -32602 `map_not_live`.
  - a `resolves-under` edge created via `mindmap_link` alone does NOT settle a node (still `open`, still in open_loops).
  - open_loops: owner- and model-responsible open nodes listed; node with no responsible_party not listed; root not
    listed; after resolve, node gone from open_loops.
  - get defaults: settled node absent from `nodes`, present in `resolved` with summary/status/party;
    `include="all"` returns it in `nodes` with `status="resolved"`.
  - depth: >200-char node truncated with `…` and `truncated=True` by default; `depth="full"` returns whole content.
  - since: `get()` → cursor c; `get(since=c)` → no nodes, no resolved, same cursor; write a node → `get(since=c)`
    returns just that node and a larger cursor; resolve a node → `get(since=c2)` shows it in `resolved`.
- Migration sanity: a test (or at least the e2e) that the CHECK rejects a bogus status
  (`UPDATE memory_map_membership SET status='bogus'` → `asyncpg.CheckViolationError`).

## Acceptance / verification — report exact results

1. `alembic upgrade head` (and `alembic downgrade -1 && alembic upgrade head`) succeed.
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_resolve_e2e.py` all pass.
3. `pytest -q -p no:cacheprovider` full suite: report the failing test list. Compare with baseline by running
   the full suite on a clean stash (`git stash -u` → run → `git stash pop`, NB the DB will be at the new head;
   that's fine) OR by reasoning per failure — tell me explicitly which failures are pre-existing and whether
   any failure involves mindmap tests (e.g. `tests/integration/test_mindmap_e2e.py` asserting full content /
   all nodes from `mindmap_get` under the new cheap defaults). Do NOT edit existing tests; if one breaks
   because of the new defaults, report it to me with the exact assertion.
4. `ruff check src tests`, `ruff format --check` on the files you touched, and `mypy` — clean for your files.

Reply with: files changed, test commands + exact pass/fail counts, any decision you made that this order didn't cover.
