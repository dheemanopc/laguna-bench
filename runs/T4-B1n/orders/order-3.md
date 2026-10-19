# Work order 3 — revert out-of-scope changes

Some of the order-2 changes changed existing behaviour or config to make *your own new tests* pass. That is
the wrong direction: fix the new tests, not the product/config. Please:

1. **Revert the `archive_map` change** in `src/mem_mcp/mindmap/service.py` (do NOT reset
   `writes_since_review` on archive — closing a map is not a review; that is existing, out-of-scope
   behaviour). Fix `test_get_works_after_archive` in `tests/integration/test_mindmap_resolve.py` to not
   assert `writes_since_review == 0` (assert what is actually relevant: state `archived`, nodes still
   readable with statuses, `cursor` returned).
2. **Revert `extra="forbid"` on `MindmapGetInput`** (backward compatibility for existing callers of
   `mindmap_get`; the task says existing callers must keep working). Remove/adjust the unit test that
   asserted extra fields are rejected for `MindmapGetInput` (keep the one for `MindmapResolveInput`, a new
   tool, which keeps `extra="forbid"`).
3. **Revert the `pyproject.toml` change entirely.** Instead make the new test module type-clean itself:
   e.g. narrow outputs with `assert isinstance(out, MindmapGetOutput)` / small typed helper functions
   (`async def _get(ctx, **kw) -> MindmapGetOutput`) and `assert exc.value.data is not None` before
   indexing. If mypy's config does not cover `tests/` at all, say so and skip this.
4. **Revert the two unrelated `# type: ignore[no-any-return]` additions** on pre-existing functions in
   `service.py` (`resolve_map_root`, `find_live_map_seeded_from`) unless `mypy` on `src` reports a NEW
   error there caused by your change — if so, explain.

## Verification — report exact results, concisely (< 50 lines)
- `pytest -q -p no:cacheprovider tests/unit/test_mindmap_cheap_reads.py tests/integration/test_mindmap_resolve.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
- `ruff check src tests`; `mypy` (report total error count and confirm none are in files you created/changed).
- Full suite `pytest -q -p no:cacheprovider`: counts, and confirm the failing set is pre-existing:
  `git stash -u`, rerun ONLY the failing test files from the full run, compare counts, `git stash pop`,
  then `git status` to confirm all your files are back. (The DB stays at head — that's fine.)
- `git diff --stat` at the end.
