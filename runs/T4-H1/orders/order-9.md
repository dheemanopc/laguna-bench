# Work order 9 — mypy cleanliness of our files

The project mypy config (`strict = true`, files include `tests`) reported 37 errors in 4 files.

1. Run `mypy 2>&1 | grep -E '^[^ ]+\.py:' | cut -d: -f1 | sort | uniq -c` and paste the output.
2. Run `mypy src/mem_mcp/mindmap/service.py src/mem_mcp/mcp/tools/mindmap_get.py src/mem_mcp/mcp/tools/mindmap_resolve.py tests/integration/test_mindmap_resolve_e2e.py tests/unit/test_mindmap_get_shaping.py alembic/versions/0044_2026_10_15_mindmap_branch_status.py`
   and paste the output.
3. Fix every error that is in one of **our** new/changed files (the six above, plus `main.py` /
   `tool_descriptions.py` if listed) with proper types (e.g. the `env` fixture should be annotated
   `AsyncIterator[MindmapTestEnv]`; avoid blanket `# type: ignore` — use a specific code only where unavoidable,
   and `warn_unused_ignores` is on). Do not touch errors in files we did not change.
4. Re-run step 2 (must be clean) and
   `pytest -q -p no:cacheprovider tests/integration/test_mindmap_resolve_e2e.py tests/unit/test_mindmap_get_shaping.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py 2>&1 | tail -3`,
   `ruff check src tests | tail -2`, and `ruff format --check` on the files you edited. Paste the outputs.
