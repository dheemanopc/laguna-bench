# Work order 5 — verification only (no code changes unless a test fails)

Your shell commands were denied last time after the first one. Use ONLY simple, single commands — no `&&`, no
`;`, no pipes, no `cd`, no `rm`. Run them one at a time, in this order, and paste the tail of each output:

1. `alembic upgrade head`
2. `pytest -q -p no:cacheprovider tests/unit/test_mindmap_resolve_get_models.py tests/integration/test_mindmap_resolve_e2e.py tests/integration/test_mindmap_e2e.py tests/unit/test_lint_tenant_scope.py`
3. `ruff check src tests alembic/versions`
4. `ruff format --check src/mem_mcp/mindmap src/mem_mcp/mcp/tools/mindmap_get.py src/mem_mcp/mcp/tools/mindmap_resolve.py tests/integration/test_mindmap_resolve_e2e.py tests/unit/test_mindmap_resolve_get_models.py alembic/versions/0044_2026_10_16_mindmap_branch_status.py`
5. `mypy`
6. `pytest -q -p no:cacheprovider -rfE` (full suite; report the summary line and every FAILED/ERROR id).
7. `git clean -f tests/integration/test_debug_open_loops.py tests/integration/test_jsonb_cast.py tests/integration/test_jsonb_minimal.py`
8. `git status --short`

If a mindmap test fails or ruff/format/mypy reports something in our changed files, fix it (format with
`ruff format <file>`) and re-run that step. If a failure in step 6 is in a test file unrelated to mindmap, just list
it — do not fix it. For each failing non-mindmap test, state whether it touches mindmap code or the
`memory_map_membership` table (grep the test file).

If a command is denied, report exactly which one and the denial message, then continue with the next command.
