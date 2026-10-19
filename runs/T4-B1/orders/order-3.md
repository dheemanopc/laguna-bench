# Work order 3 — final small fix

The feature looks good. One scope issue remains:

1. `src/mem_mcp/main.py`: you hoisted the whole `tools_list` out of `_wire_routers` to module level so a test
   could import it. That's an unrequested refactor of app wiring. Revert it: `tools_list` goes back inside
   `_wire_routers` exactly as before, with `MindmapResolveTool` added after `MindmapCloseTool`; keep the new
   import (alphabetical, as now). The only diff in `main.py` should be those two added lines.
2. Fix `tests/unit/test_mindmap_resolve_models.py::test_tools_registered_in_main` (your own new test) to
   verify registration without that hoist — prefer the way existing tests check registered tools (look at
   `tests/unit/test_mcp.py::test_tools_list` and any app/registry fixture; e.g. build the app / registry and
   assert `"mindmap_resolve"` is registered with scope `memory.write`). If building the app is impractical in a
   unit test, inspect `_wire_routers`' source with `inspect.getsource` for `MindmapResolveTool` as a fallback.

Verify and report exact results:
- `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_models.py tests/integration/test_mindmap_branch_status.py tests/integration/test_mindmap_e2e.py tests/unit/test_mcp.py tests/unit/test_lint_tenant_scope.py`
- `ruff check src tests` and `ruff format --check` on the files of this feature.
- `git diff --stat` (paste it).
Do not commit.
