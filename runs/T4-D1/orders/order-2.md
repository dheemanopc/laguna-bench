# Work order 2 — finish & fix order 1

Good core work. The following must be fixed / finished. Keep the design from order 1.

## 1. Remove scratch files from the repo root
Delete: `CHANGES_SUMMARY.txt`, `FINAL_REPORT.txt`, `IMPLEMENTATION_SUMMARY.md`, `VERIFICATION_REPORT.md`,
`fix_context.py`, `fix_pool_references.py`, `fix_tests.py`, `verify_implementation.sh`.
`git status` afterwards must show only: the migration, `main.py`, `tool_descriptions.py`, `mindmap_get.py`,
`mindmap_resolve.py`, `mindmap/service.py`, the two new test files, and the two doc files below.

## 2. `mindmap_get.py` fixes
- **`open_loops` must always be computed over the WHOLE map** (all members: `status == "open"` and
  `metadata.responsible_party == "owner"`), before any `since` filtering. Today the `since`-with-no-changes
  early return sends `open_loops=[]`, and the normal `since` path computes it only over touched nodes —
  both wrong. Remove the early-return duplication; let the one code path produce empty `nodes`/`resolved`/
  `edges` naturally when nothing was touched.
- **Edges**: fetch internal edges over ALL member ids (not the since-filtered subset), then keep edges with
  **at least one** endpoint among the returned `nodes` ∪ `resolved` ids (currently it's AND). When nothing
  is returned, edges = [].
- Move `CONTENT_TRUNCATION_LIMIT` to a module-level constant (e.g. `SUMMARY_CONTENT_CHARS = 200`) and the
  truncation into a small module-level pure helper (e.g. `_summarize_content(content, depth) -> tuple[str,
  bool]`) that the unit test exercises directly.
- Update the module docstring: explain since/cursor/include/depth and why (resume cost should scale with
  open work, not total discussion).

## 3. `mindmap_resolve.py` fixes
- Move `REFERENCE_KINDS` to a module-level constant (e.g. `_EDGE_KIND_FOR_DISPOSITION`), with a comment
  pointing at the design doc's reference-kind vocabulary.
- Delete the unused duplicate `MindmapResolvedEntry` class.
- Event payload `reference_kind` must be `None` when no resolving node was given (no edge was written).
- Expand the module docstring: why status is stored (not inferred from edges), edge direction
  (resolver → settled node), one transaction, archived maps refuse (no-reopen), root refused.

## 4. `service.py`
- `current_cursor`: return `int(...)` (mypy). Ensure `tools/lint_tenant_scope.py` passes on the new SQL
  (`pytest -q -p no:cacheprovider tests/unit/test_lint_tenant_scope.py`); if it flags the
  `memory_map_events` queries, add an explicit `AND tenant_id = $n` filter (pass `tenant_id` in) rather
  than exempting.

## 5. Docs (not done yet)
- `docs/mindmap-v1-build-design.md`: add `mindmap_resolve` row to the tool table; add the new
  `memory_map_membership` status columns to the schema sketch; note `mindmap_get`'s
  `since`/`include`/`depth` levers + `cursor` + `resolved` list; open_loops = owner-turn AND status open.
- `skills/mindmap-driver/SKILL.md`: settle branches with `mindmap_resolve` (summary required; pass the
  resolving node when there is one); resume with `mindmap_get(since=<last cursor>)`; use
  `include="all"`/`depth="full"` only when needed.

## 6. Integration tests must actually pass
Your report said `tests/integration/test_mindmap_branch_status.py` "needs helper fixes". Fix the test
file (it's your new file, so editing it is fine) until every test passes, covering the scenarios listed in
order 1 (resolve with/without resolver + edge kinds + event + cursor; other-map node / random uuid / root /
unknown map / archived map / inaccessible resolver → -32602 with DB unchanged; open_loops before/after
resolve, model-turn never listed; default get puts settled branch in `resolved` not `nodes`; truncation;
include="all"; depth="full"; since/cursor sequence incl. `since` with no changes → no nodes + same cursor
**and open_loops still populated**; a resolve then get(since) returns the node in `resolved`; edges
returned with since when one endpoint touched; DB CHECK rejects bad status/party and status='resolved'
with NULL summary).

## 7. Formatting / lint
`ruff format` the new/changed files (migration lines are >100 cols now; import order in
mindmap_resolve.py), then `ruff check src tests` and `mypy` clean for changed files.

## Report exact outputs of
1. `alembic upgrade head`
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_branch_status.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
3. Full suite `pytest -q -p no:cacheprovider` — paste the final summary line and the list of FAILED/ERROR
   test ids. Then `git stash -u`, rerun the full suite on the baseline (note: baseline code + DB already at
   0044 is fine — it's additive), paste its failure list, `git stash pop`. Confirm no new failures.
4. `ruff check src tests`, `mypy` (summary lines).
5. `git status`.
