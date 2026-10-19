# Work order 4 — complete the resolve/get test suite (tests only)

Do not change `src/` unless a test exposes a real bug (then report exactly what and why).

The refactor in order 3 **deleted** previously passing tests (dropped disposition, unknown map, root refusal,
include="all" status, open_loops-after-resolve), and most of order 3 §B was still not implemented. Below is the
exact list of test functions that must exist in `tests/integration/test_mindmap_resolve_e2e.py` when you are done
(use the existing `env` fixture and helpers; add helpers as needed, e.g. `_link`, `_close`, `_row(env, node_id)`
returning the full membership row, `_resolve_events(env, root_id, node_id)` returning event rows **with payload**
filtered to `event='resolve' AND memory_id=node_id`). Also fix the annotations: tests use `env: TestEnv` — use the
actual fixture type `MindmapTestEnv` everywhere. `_open` should return the full open output (so tests have
`root_memory_id`) or add a separate helper.

Check off every item; each must assert exactly what is stated.

1. `test_resolve_without_resolver` (keep) — also assert DB row `resolution_summary`, `resolved_by_party == "model"`,
   `resolved_at IS NOT NULL`, `resolved_by_memory_id IS NULL`.
2. `test_resolve_with_resolver_node` (keep) — also assert DB `resolved_by_memory_id == resolver_id` and exactly
   one `resolve` event for the node with `payload["reference_kind"] == "resolves-under"`.
3. `test_dropped_with_resolver_creates_dropped_under_edge` — status `dropped`, edge kind `dropped-under`,
   source = resolver.
4. `test_dropped_without_resolver` — `resolved_by_party="owner"`; status `dropped`, no edge targeting the node,
   exactly one resolve event with `actor == "owner"` and `payload["disposition"] == "dropped"`.
5. `test_unknown_map` — `map_key="no-such-map-<uuid hex>"` → -32602, `data == {"errors":[{"path":"map_key"}]}`.
6. `test_cross_map_node_rejected` (keep) — additionally: no resolve event in map A **or** map B (use the roots).
7. `test_cross_map_and_random_uuid_errors_identical` — compare `(code, message, data)` of the cross-map error and
   the random-uuid error on the same map: equal.
8. `test_root_cannot_be_settled` — resolving `root_memory_id` → -32602 path `node_id`; root row status `open`.
9. `test_archived_map_rejected` (keep).
10. `test_resolver_not_accessible` — `resolved_by_memory_id=uuid4()` → -32602 `data["code"] ==
    "memory_not_accessible"`; node status `open`; no resolve event.
11. `test_resolver_equal_to_node_rejected` — -32602; node `open`.
12. `test_target_team_id_correct` (keep).
13. `test_link_alone_no_settle` (keep) — but write B with the real field `responsible_party="owner"` (not
    metadata), and also assert DB status of B is `open`.
14. `test_open_loops_whose_turn` — owner node O (`responsible_party="owner"`), model node M
    (`responsible_party="model"`), plain node P (none): `open_loops` contains O and M, not P, not root. Then resolve
    O and drop M → `open_loops` contains neither.
15. `test_include_open_default_and_all` — resolve node S with `resolved_by_party="owner"`, leave node K open.
    Default get: S not in `nodes`, S in `resolved` with `resolution_summary`, `status == "resolved"`,
    `resolved_by_party == "owner"`; K in `nodes` with `status == "open"`. `include="all"`: S in `nodes` with
    `status == "resolved"`, `resolved == []`.
16. `test_depth_summary_truncation` (keep) — use non-uniform content (e.g. `"".join(str(i % 10) for i in
    range(250))`) and assert `content[:200] == original[:200]`; also the default get (no depth arg) truncates.
17. `test_depth_full_no_truncation` (keep) — also assert `content == original`.
18. `test_depth_exactly_200_not_truncated` — 200-char node unchanged, `truncated is False` in summary depth.
19. `test_since_no_change_returns_nothing` — `c0 = get().cursor`; `get(since=c0)` → `nodes == []`,
    `resolved == []`, `cursor == c0`.
20. `test_since_returns_only_touched` — write A, B; `c0`; write X → `get(since=c0)` node ids `== [X]` exactly,
    cursor > c0.
21. `test_since_link_touches_both_endpoints` — A, B written; `c1 = get().cursor`; `mindmap_link(A→B,
    reference_kind="principle-under", map_key=…)` → `get(since=c1)` node ids `== {A, B}` and edge A→B in `edges`.
22. `test_since_after_resolve` — X written; `c2 = get().cursor`; `r = resolve(X)` → `r.cursor > c2`,
    `r.cursor == get().cursor`; `get(since=c2)`: X in `resolved`, `nodes == []`.
23. `test_since_beyond_cursor` — `get(since=10**12)` → empty nodes/resolved, `cursor == get().cursor`.
24. `test_resolve_is_atomic_when_edge_insert_fails` — `monkeypatch.setattr(
    "mem_mcp.mcp.tools.mindmap_resolve.insert_reference", _boom)` where `_boom` is an async fn raising
    `RuntimeError`; resolve with a resolver → `pytest.raises(RuntimeError)`; DB row status `open`,
    `resolution_summary IS NULL`; zero resolve events for the node.
25. `test_resettle_overwrites` — resolve (summary "first") then dropped (summary "second") → DB status `dropped`,
    summary "second"; default get has the node exactly once in `resolved`, not in `nodes`.

Keep the unit tests in `tests/unit/test_mindmap_get_shaping.py`, and make sure a test there checks that
`MindmapResolveInput(..., resolution_summary="   ")` raises `ValidationError` (if it already does, fine).

## Verification — paste real output, don't summarise
1. `pytest -q -p no:cacheprovider tests/integration/test_mindmap_resolve_e2e.py -v 2>&1 | tail -40` (I want to
   see all 25 names PASSED).
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_get_shaping.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
3. Full suite before/after comparison, pasting the outputs:
   ```
   pytest -q -p no:cacheprovider 2>&1 | grep -E '^(FAILED|ERROR) ' | sed 's/ - .*//' | sort > /tmp/after.txt; tail -1 of the run
   git stash -u
   pytest -q -p no:cacheprovider 2>&1 | grep -E '^(FAILED|ERROR) ' | sed 's/ - .*//' | sort > /tmp/before.txt
   git stash pop && git status --short
   wc -l /tmp/before.txt /tmp/after.txt; comm -13 /tmp/before.txt /tmp/after.txt
   ```
   (`comm -13` output must be empty.) Use `-rfE` if FAILED lines don't appear in -q output.
4. `ruff check src tests`; `ruff format --check` on the two test files; `mypy`.
