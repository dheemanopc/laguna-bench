# Work order 8 — failure list without stash (no code changes)

Skip the stash comparison. Run only these (each is an ordinary test/lint command) and paste literal output:

1. `pytest -q -p no:cacheprovider -rfE 2>&1 | grep -E '^(FAILED|ERROR) ' | sed 's/ - .*//' | sort -u`
   followed by the final summary line of that run.
2. For that list, state for each failing test **file** whether it imports or exercises anything from
   `mem_mcp.mindmap`, `mem_mcp.mcp.tools.mindmap_*`, `mem_mcp.mcp.tool_descriptions` or `mem_mcp.main`
   (grep the test file). For any that does, show its failure message.
3. `ruff check src tests | tail -3`
4. `ruff format --check src/mem_mcp/mindmap/service.py src/mem_mcp/mcp/tools/mindmap_get.py src/mem_mcp/mcp/tools/mindmap_resolve.py alembic/versions/0044_2026_10_15_mindmap_branch_status.py tests/integration/test_mindmap_resolve_e2e.py tests/unit/test_mindmap_get_shaping.py`
5. `mypy 2>&1 | tail -3`
