# Work order 3 — the missing tests (order 2 §6) + full-suite evidence

The source fixes from order 2 look correct — **do not change `src/` unless a new test exposes a real bug** (if it
does, fix it and tell me exactly what and why).

Order 2 §6 was not done: `tests/integration/test_mindmap_resolve_e2e.py` still has the same 10 tests as after
order 1, and no fixture refactor happened. Please do it now.

## A. Refactor the test file
Replace the per-test copy-pasted setup/ctx/cleanup with one async pytest fixture (in the test file) that creates the
UUID-suffixed tenant/team/identity/oauth client, yields a small object (e.g. a dataclass with `ctx`, `tenant`,
`team`) and runs the cleanup in teardown. Add small helpers (`_open(env, title)`, `_write(env, map_key, content,
**kw)`, `_resolve(env, ...)`, `_get(env, map_key, **kw)`, `_status(env, node_id)`, `_events(env, root_id)`,
`_edges_to(env, node_id)`). Keep every existing test's assertions (you may rewrite them on the fixture).

## B. Add these tests (each asserts DB state/outputs, not just "no exception")
1. **Cross-map**: open map A and map B (same tenant/team); write node `b1` in B; `mindmap_resolve(map_key=A,
   node_id=b1)` → `JsonRpcError` -32602, `data == {"errors":[{"path":"node_id"}]}`; `b1` status still `open`;
   no `resolve` event in either map; no edge targeting `b1`. Then `node_id=uuid4()` on A → identical code, message
   and data.
2. **Archived map**: open, write a node, `mindmap_close(map_key, confirmed_decisions=[])`, then resolve that node →
   -32602 with `data["code"] == "map_not_live"`; node still `open`.
3. **Dropped without resolver**: status `dropped`, `resolved_by_memory_id IS NULL`, no edge targeting the node,
   exactly one `resolve` event for it with `actor == "owner"` when `resolved_by_party="owner"` and payload
   `disposition == "dropped"`.
4. **Resolver not accessible**: `resolved_by_memory_id=uuid4()` → -32602 `data["code"] == "memory_not_accessible"`;
   node still `open`, no event.
5. **Edge target team**: after resolve with a resolver, `memory_references.target_team_id` for the new edge equals
   the map's team.
6. **Edge alone never settles**: `MindmapLinkTool` with `reference_kind="resolves-under"` from node A to node B
   (B written with `responsible_party="owner"`) → B `status == "open"`, B in default `get().nodes`, B in
   `open_loops`, B not in `resolved`.
7. **open_loops whose-turn**: nodes written with `responsible_party="owner"` and `responsible_party="model"` (the
   `MindmapWriteNodeInput.responsible_party` field) are both in `open_loops`; a node without it is not; the root is
   not; after resolving the owner one and dropping the model one, neither is in `open_loops`.
8. **include**: after resolving a node with `resolved_by_party="owner"`: default get → absent from `nodes`, present
   in `resolved` with `resolution_summary`, `status == "resolved"`, `resolved_by_party == "owner"`;
   `include="all"` → present in `nodes` with `status == "resolved"`, `resolved == []`, and open nodes have
   `status == "open"`.
9. **depth via the tool**: node with 250 chars → default get: `len(content) == 201`, ends with `"…"`, first 200
   chars equal the original's first 200, `truncated is True`; `depth="full"` → original content,
   `truncated is False`; a node with exactly 200 chars → unchanged, `truncated is False`.
10. **since**:
    - `c0 = get().cursor`; `get(since=c0)` → `nodes == []`, `resolved == []`, `cursor == c0`.
    - write X → `g = get(since=c0)` → `[n.memory_id for n in g.nodes] == [X]`, `g.cursor > c0`.
    - `c1 = g.cursor`; `mindmap_link(A→B, map_key=…)` with A, B existing members written before c0 →
      `get(since=c1)` node ids == {A, B} and the A→B edge is in `edges`.
    - `c2 = get().cursor`; resolve X → `r.cursor > c2` and `r.cursor == get().cursor`; `get(since=c2)` → X in
      `resolved`, not in `nodes`.
    - `get(since=10**12)` → `nodes == []`, `resolved == []`, `cursor == get().cursor`.
11. **Atomicity**: `monkeypatch.setattr("mem_mcp.mcp.tools.mindmap_resolve.insert_reference", <async fn that
    raises RuntimeError>)`; resolve with a resolver → `RuntimeError` propagates; node status `open`,
    `resolution_summary IS NULL`, no `resolve` event for the node.
12. **Re-settle**: resolve, then resolve again with `disposition="dropped"` and a new summary → status `dropped`,
    new summary; get(default) lists it once in `resolved`.
13. **Unit (tests/unit/test_mindmap_get_shaping.py)**: add `MindmapResolveInput` validation tests: missing summary,
    `""`, `"   "`, 501 chars → `ValidationError`; 500 chars ok; `disposition="closed"`, `resolved_by_party="user"`,
    unknown extra field → `ValidationError`; defaults `disposition == "resolved"`, `resolved_by_party == "model"`.

## C. Verification — report the exact commands and paste the summary lines
1. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_get_shaping.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
2. Full suite with change: `pytest -q -p no:cacheprovider -rf 2>&1 | grep -E '^(FAILED|ERROR)' | sort > /tmp/after.txt`
   plus the final summary line.
3. Baseline: `git stash -u && pytest -q -p no:cacheprovider -rf 2>&1 | grep -E '^(FAILED|ERROR)' | sort > /tmp/before.txt; git stash pop`
   (verify `git status` afterwards shows all your files back).
4. `comm -13 /tmp/before.txt /tmp/after.txt` — must be empty; paste its output (and the counts of both files).
5. `ruff check src tests`, `ruff format --check <touched files>`, `mypy` — paste results.
