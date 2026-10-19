# Work order 2 — fixes after review of order 1

Good structure overall. The following must be fixed. Do not modify pre-existing tests.

## 1. Wrong `target_team_id` on the resolve edge (bug) — `mindmap_resolve.py`
`insert_reference(target_team_id=...)` must be the team of the **target** (the settled node, `node_id`), but you
currently pass the team of the **resolver** (`resolved_by_memory_id`, which is the edge *source*). Fix:
- Get the settled node's team the way `mindmap_link` does for its target: `resolve_reference_target(sys_conn,
  target_uuid=inp.node_id, caller_user_id=ctx.tenant_id)` in a `system_tx` before the write tx. If that raises
  `ReferenceTargetNotFoundError`, raise the SAME error as "not a member of this map" (-32602, message
  "node is not a member of this map", `data={"errors":[{"path":"node_id"}]}`) — opaque. (Alternatively take
  `memories.team_id` for the node from the membership query inside the tenant tx — either is fine, but do it
  only when an edge is being written, and keep the opaque error.) Unknown map must still be reported as
  "map not found" first: do the map-key resolution before anything node-related (you can resolve team/map in a
  first read in the tenant tx and re-lock in the write tx, or do the node team lookup inside the write tx via
  the membership join — the latter is simpler; prefer it: extend `get_membership_for_update` to also return
  `m.team_id`).
- The resolver (edge source) must be a non-deleted memory **of the caller's tenant**: use the existing (currently
  unused) `service.memory_visible_in_tenant` inside the write tx; failure → -32602
  `data={"code":"memory_not_accessible","errors":[{"path":"resolved_by_memory_id"}]}`. Remove the
  `resolve_reference_target` call on the resolver. Order of checks in the write tx: map found → map live →
  node membership → root refusal → resolver visible → update → edge → event.
- Add a test asserting `memory_references.target_team_id` of the new edge equals the map's team.

## 2. `touched_member_ids_since` is wrong (bug) — `service.py`
`COALESCE(memory_id, payload->>'target')` never yields link targets (link events always have `memory_id` set to
the source). Also `UUID(r["touched_id"])` on a value asyncpg already returns as a UUID is fragile. Rewrite as a
UNION of `memory_id` and the `payload->>'target'` text (only where it's present), cast safely — e.g. select
`memory_id::text` and `payload->>'target'` as text, and compare as strings to the member ids, or restrict the
query by joining against `memory_map_membership` for this root/tenant (`mm.memory_id::text = t.touched`) and
return `set[UUID]` of member ids directly. Must not error on non-UUID garbage in payload.

## 3. Pydantic input validation — `mindmap_resolve.py`
- Use `model_config = ConfigDict(extra="forbid")` (import from pydantic), like other inputs in the repo.
- `validate_resolution_summary` is a plain staticmethod and never runs. Make it a real
  `@field_validator("resolution_summary")` rejecting whitespace-only. Keep the tool-level check as well (harmless)
  or drop it — your choice; update the existing whitespace test accordingly (it's your new test, you may edit it):
  constructing the input with `"   "` must raise `pydantic.ValidationError`.
- Also give `MindmapGetInput` `model_config = ConfigDict(extra="forbid")`? **No** — leave `MindmapGetInput`'s
  extra handling as it was (backward compat).

## 4. Edges in `mindmap_get`
Edges must be internal edges (both endpoints map members) with **at least one** endpoint among the ids returned in
`nodes` ∪ `resolved`. Currently with `since` you pass only the touched ids so an edge from a newly written node
to an older untouched member is dropped. Fetch internal edges over all member ids, then filter in Python (or a
service function with two id arrays).

## 5. Docstrings
- `mindmap_get.py` module docstring still says open loops = owner only. Update: open loops = open (unsettled)
  nodes carrying a `responsible_party` (owner or model) — whose-turn; settled branches never.
- Same for the `mindmap_get` text in `tool_descriptions.py` ("open_loops lists nodes whose turn is the owner's"):
  make it say open loops are unsettled nodes with a responsible party (owner = waiting on the user, model = on
  you), and mention `mindmap_resolve` removes a branch from it. Fix the depth wording: "default: 200 chars + …"
  should say summary depth (the default) cuts content over 200 chars to 200 + "…" and sets `truncated`.
- `mindmap_resolve.py` docstring: explain why status is stored rather than inferred from `reference_kind`.
- Migration: run `ruff format` on it (the downgrade has an odd wrap) — and make the long CHECK lines < 100 cols.

## 6. Missing tests (order 1 §F was only partly done) — `tests/integration/test_mindmap_resolve_e2e.py`
First, de-duplicate: move setup/cleanup/ctx into a pytest fixture (e.g. an async fixture yielding
`(ctx, team, tenant)` and cleaning up after) so each test is short. Then add (assert DB state / outputs, not just
"no exception"):
1. node of a **different map** in the same tenant/team → -32602 path `node_id`; its status in its own map is
   unchanged (`open`) and no edge/event was added in either map. Random UUID → identical error (code, message,
   data).
2. archived map (after `mindmap_close` with no decisions) → -32602 `data["code"] == "map_not_live"`.
3. `dropped` **without** resolver → status `dropped`, no edge, `resolve` event logged with actor = party.
4. resolver not visible (random UUID) → -32602 `memory_not_accessible`, node still open.
5. `mindmap_link(reference_kind="resolves-under")` from another node to an open node does NOT settle it: still
   `status == "open"`, still in `nodes` for include=open, still in `open_loops` (it has responsible_party).
6. open_loops: node with `responsible_party="owner"` and node with `responsible_party="model"` (use the
   `responsible_party=` input field of `MindmapWriteNodeInput`, not metadata) both included; node without one
   excluded; root excluded; after resolve/drop, excluded.
7. `include="all"`: settled node in `nodes` with `status`, `resolved == []`. Default include: settled node absent
   from `nodes`, present in `resolved` with `resolution_summary`, `status`, `resolved_by_party == "owner"` when
   resolved by owner.
8. depth through the tool: a 250-char node → default get gives 201-char content ending in "…", `truncated=True`;
   `depth="full"` gives 250 chars, `truncated=False`; a 200-char node unchanged, `truncated=False`.
9. `since`: `g0 = get()` → `c0 = g0.cursor`; `get(since=c0)` → `nodes == []`, `resolved == []`,
   `cursor == c0`; write node X → `get(since=c0)` returns exactly `[X]` in nodes and `cursor > c0`;
   `mindmap_link` A→B (both existing members) → `get(since=c1)` returns A and B (link target counted) and the edge;
   resolve X → returned `cursor` equals a subsequent `get().cursor`; `get(since=c_before_resolve)` → X in
   `resolved`, not in nodes; `get(since=<huge number>)` → no nodes, current cursor.
10. resolve output `cursor` strictly greater than the cursor before the call.
11. Atomicity: monkeypatch `mem_mcp.mcp.tools.mindmap_resolve.insert_reference` to raise; call resolve with a
    resolver → the exception propagates, node status is still `open`, no `resolve` event and no edge exist.
12. Re-settle: resolve then drop the same node → final status `dropped`, summary updated.

## Verification (report exact commands and outputs)
- `alembic upgrade head`
- `pytest -q -p no:cacheprovider tests/unit/test_mindmap_get_shaping.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
- **Full suite** `pytest -q -p no:cacheprovider` — you did not report it last time. List every failing test id.
  Then `git stash -u`, rerun the full suite on the baseline (DB stays migrated — that's fine), `git stash pop`, and
  show that the set of failures with your change ⊆ baseline failures.
- `ruff check src tests`, `ruff format --check` on all touched/new files, `mypy` (project config) — report
  results; any new errors in your files must be fixed. If you added `# type: ignore[no-any-return]` to existing
  functions in service.py, only keep them if mypy actually requires them.
